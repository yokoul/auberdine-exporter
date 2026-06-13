// Package app assemble le démon : découverte des fichiers, surveillance par
// polling léger, transmission des exports et des segments de log de donjon.
package app

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/selfupdate"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
	"github.com/yokoul/auberdine-exporter/uploader/internal/version"
)

// updateCheckInterval est la cadence de re-vérification des mises à jour du
// binaire, en plus du contrôle au démarrage (handshake).
const updateCheckInterval = 24 * time.Hour

// maxSavedVarsSize plafonne la lecture d'une SavedVariable (chargée entière
// en mémoire pour le parse) — garde-fou contre un fichier aberrant.
const maxSavedVarsSize = 64 << 20

// App est le démon de l'uploader.
type App struct {
	paths    discovery.Paths
	state    *State
	uploader upload.Uploader
	logger   *log.Logger

	paused atomic.Bool

	// mu protège la configuration mutable (consentement, clé API) et sa
	// persistance. Le tray peut la modifier à chaud pendant que tick() la lit.
	mu  sync.Mutex
	cfg config.Config

	apiKeyWarned bool

	// addonWarned mémorise les versions d'addon déjà signalées comme trop
	// anciennes (clé : chemin SV + version) — un avertissement par démarrage,
	// pas un par cycle de poll.
	addonWarned map[string]bool
}

// New construit le démon à partir de la configuration. Le client d'upload peut
// être injecté (tests) ; s'il est nil, un client HTTP est créé.
func New(cfg config.Config, up upload.Uploader, logger *log.Logger) (*App, error) {
	paths, ok := discovery.Detect(cfg.WoWPath)
	if !ok {
		return nil, fmt.Errorf("installation WoW introuvable (configurez wowPath)")
	}
	st, err := LoadState()
	if err != nil {
		return nil, err
	}
	if logger == nil {
		logger = log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	}
	a := &App{paths: paths, state: st, logger: logger, cfg: cfg}
	if up == nil {
		up = upload.NewHTTP(cfg.Endpoint, a.APIKey)
	}
	a.uploader = up
	return a, nil
}

// APIKey renvoie la clé d'ingestion courante (thread-safe).
func (a *App) APIKey() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg.APIKey
}

// HasAPIKey indique si une clé d'ingestion est configurée.
func (a *App) HasAPIKey() bool { return a.APIKey() != "" }

// Endpoint renvoie la base de l'API d'ingestion (thread-safe).
func (a *App) Endpoint() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg.Endpoint
}

// dedupKey namespace une clé de dédup (fichier d'export ou run de donjon) par
// endpoint, pour que les envois vers dev et prod soient suivis SÉPARÉMENT. Sans
// ça, un payload déjà transmis à un environnement est considéré « déjà envoyé »
// pour l'autre (un seul state.json partagé) → jamais ré-uploadé après bascule.
func (a *App) dedupKey(s string) string {
	return a.Endpoint() + "|" + s
}

// SetAPIKey enregistre la clé d'ingestion obtenue par la connexion et persiste.
func (a *App) SetAPIKey(key string) error {
	a.mu.Lock()
	a.cfg.APIKey = key
	cfg := a.cfg
	a.mu.Unlock()
	return cfg.Save()
}

// UploadExports indique si la transmission des exports est active.
func (a *App) UploadExports() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg.UploadExports
}

// UploadDungeonLogs indique si la transmission des logs de donjon est active.
func (a *App) UploadDungeonLogs() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg.UploadDungeonLogs
}

// SetUploadExports active/désactive la transmission des exports et persiste.
func (a *App) SetUploadExports(v bool) error {
	a.mu.Lock()
	a.cfg.UploadExports = v
	cfg := a.cfg
	a.mu.Unlock()
	return cfg.Save()
}

// SetUploadDungeonLogs active/désactive la transmission des logs de donjon et persiste.
func (a *App) SetUploadDungeonLogs(v bool) error {
	a.mu.Lock()
	a.cfg.UploadDungeonLogs = v
	cfg := a.cfg
	a.mu.Unlock()
	return cfg.Save()
}

// SetPaused met en pause (ou reprend) la transmission. La surveillance continue
// mais aucune donnée n'est envoyée tant que la pause est active.
func (a *App) SetPaused(p bool) { a.paused.Store(p) }

// Paused indique l'état de pause courant.
func (a *App) Paused() bool { return a.paused.Load() }

// Paths expose les chemins résolus (diagnostic).
func (a *App) Paths() discovery.Paths { return a.paths }

// Run lance la boucle de surveillance jusqu'à annulation du contexte.
func (a *App) Run(ctx context.Context) error {
	a.mu.Lock()
	interval := time.Duration(a.cfg.PollIntervalSeconds) * time.Second
	a.mu.Unlock()
	if interval <= 0 {
		interval = 5 * time.Second
	}
	a.logger.Printf("démarrage : %d SavedVariables, logs=%s (%d log(s) de combat présents) — version %s",
		len(a.paths.SavedVars), a.paths.LogsDir, len(discovery.ListCombatLogs(a.paths.LogsDir)), version.Version)
	selfupdate.CleanupLeftovers()
	if st, ok := a.handshake(ctx); ok {
		a.maybeSelfUpdate(ctx, st.Client)
	}

	// Premier passage immédiat, puis à intervalle régulier. La vérification de
	// mise à jour vit dans la même boucle que tick() : jamais en concurrence
	// avec un upload en cours.
	a.tick(ctx)
	t := time.NewTicker(interval)
	defer t.Stop()
	ut := time.NewTicker(updateCheckInterval)
	defer ut.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-t.C:
			a.tick(ctx)
		case <-ut.C:
			a.checkSelfUpdate(ctx)
		}
	}
}

// checkSelfUpdate interroge le serveur et applique une éventuelle mise à jour.
func (a *App) checkSelfUpdate(ctx context.Context) {
	if a.APIKey() == "" {
		return
	}
	st, err := a.uploader.Status(ctx)
	if err != nil {
		a.logger.Printf("vérification de mise à jour : %v", err)
		return
	}
	a.maybeSelfUpdate(ctx, st.Client)
}

// maybeSelfUpdate applique la mise à jour annoncée par le serveur si elle est
// plus récente que le binaire courant, puis redémarre le service. Toute erreur
// est non fatale : le démon continue sur la version en place et réessaiera au
// prochain contrôle.
func (a *App) maybeSelfUpdate(ctx context.Context, rel *upload.ClientRelease) {
	a.mu.Lock()
	disabled := a.cfg.DisableAutoUpdate
	a.mu.Unlock()
	if disabled {
		return
	}
	asset, ok := selfupdate.Available(rel)
	if !ok {
		return
	}
	a.logger.Printf("mise à jour disponible : %s → %s, téléchargement...", version.Version, rel.Latest)
	exe, err := selfupdate.Apply(ctx, asset)
	if err != nil {
		a.logger.Printf("mise à jour : %v", err)
		return
	}
	a.logger.Printf("mise à jour %s installée, redémarrage", rel.Latest)
	if err := selfupdate.Restart(exe); err != nil {
		a.logger.Printf("redémarrage : %v — la nouvelle version prendra effet à la prochaine session", err)
	}
}

// handshake valide la clé API au démarrage et signale les anomalies de config
// (clé absente/invalide, compte Discord non lié). Non bloquant. Renvoie la
// réponse du serveur (porte aussi l'annonce de release du client).
func (a *App) handshake(ctx context.Context) (upload.StatusResponse, bool) {
	if a.APIKey() == "" {
		a.logger.Print("⚠ clé API non configurée : aucun envoi tant que apiKey est vide (voir config.json)")
		return upload.StatusResponse{}, false
	}
	st, err := a.uploader.Status(ctx)
	if err != nil {
		a.logger.Printf("⚠ handshake /ingest/status : %v", err)
		return upload.StatusResponse{}, false
	}
	if !st.Partner.LinkedDiscord {
		a.logger.Print("⚠ clé API sans Discord lié : les imports passeront mais aucun personnage ne sera auto-claim")
	}
	a.logger.Printf("connecté à l'API d'ingestion (contrat v%d, clé « %s »)", st.ContractVersion, st.Partner.Label)
	return st, true
}

// tick effectue un cycle de surveillance.
func (a *App) tick(ctx context.Context) {
	if a.paused.Load() {
		return
	}
	if a.APIKey() == "" {
		if !a.apiKeyWarned {
			a.logger.Print("clé API absente : cycle ignoré (configurez apiKey)")
			a.apiKeyWarned = true
		}
		return
	}
	if a.UploadExports() {
		for _, sv := range a.paths.SavedVars {
			if err := a.processExport(ctx, sv); err != nil {
				a.logger.Printf("export %s : %v", sv, err)
			}
		}
	}
	if a.UploadDungeonLogs() {
		if err := a.processDungeonLogs(ctx); err != nil {
			a.logger.Printf("logs donjon : %v", err)
		}
	}
}

// processExport lit une SavedVariable, en extrait l'export signé publié par
// l'addon (uploaderExport.payload) et le transmet s'il a changé depuis le
// dernier envoi. L'uploader ne re-signe ni ne reconstruit l'export : il relaie
// tel quel ce que l'addon a produit (seul détenteur de la clé de signature).
func (a *App) processExport(ctx context.Context, svPath string) error {
	// Plafond de lecture (audit 2026-06, point 2) : une SavedVariable réelle
	// pèse quelques Mo ; au-delà de 64 Mo c'est un fichier aberrant qu'on
	// refuse plutôt que de le charger entier en mémoire.
	if st, err := os.Stat(svPath); err == nil && st.Size() > maxSavedVarsSize {
		return fmt.Errorf("SavedVariables anormalement gros (%d Mo > %d Mo), ignoré",
			st.Size()>>20, maxSavedVarsSize>>20)
	}
	raw, err := os.ReadFile(svPath)
	if err != nil {
		return err
	}
	parsed, err := luasv.Parse(string(raw))
	if err != nil {
		return fmt.Errorf("parse: %w", err)
	}
	db, ok := parsed["AuberdineExporterDB"].(map[string]any)
	if !ok {
		return nil // fichier présent mais sans données de l'addon
	}
	a.checkAddonVersion(svPath, db)
	exp, ok := db["uploaderExport"].(map[string]any)
	if !ok {
		return nil // l'addon n'a pas encore publié d'export signé (logout requis)
	}
	payload, _ := exp["payload"].(string)
	if payload == "" {
		return nil
	}

	sum := sha256.Sum256([]byte(payload))
	hash := hex.EncodeToString(sum[:])
	if hash == a.state.lastExportHash(a.dedupKey(svPath)) {
		return nil // inchangé : dédup
	}

	res, err := a.uploader.SendExport(ctx, payload)
	if err != nil {
		if upload.IsDefinitive(err) {
			// Payload refusé (ex. signature invalide) : inutile de le renvoyer
			// à l'identique à chaque cycle. On mémorise le hash pour ne réessayer
			// qu'au prochain export régénéré par l'addon.
			a.logger.Printf("export %s rejeté (définitif), ignoré jusqu'au prochain export : %v", svPath, err)
			return a.state.setExportHash(a.dedupKey(svPath), hash)
		}
		return err // transitoire : on réessaiera au prochain cycle
	}
	a.logger.Printf("export transmis depuis %s (%d personnage(s))", svPath, res.Processed)
	return a.state.setExportHash(a.dedupKey(svPath), hash)
}

// twinStaleAfter : âge au-delà duquel un run encore in_progress est un
// ZOMBIE de manifeste (crash du client, déconnexion en instance jamais
// suivie d'une clôture) — aucune session réelle ne dure aussi longtemps.
// Sans ce seuil, sa fenêtre « jusqu'à maintenant » différerait
// INDÉFINIMENT le groupe et avalerait toutes les sessions suivantes de la
// même instance.
const twinStaleAfter = 6 * time.Hour

// dropStaleRuns écarte les runs in_progress périmés (zombies). Ils ne sont
// PAS marqués transmis : si l'addon clôt un jour le run, il repartira.
func dropStaleRuns(runs []manifestRun, now int64) []manifestRun {
	out := runs[:0]
	for _, r := range runs {
		if r.Status != "complete" && now-r.StartedAt > int64(twinStaleAfter/time.Second) {
			continue
		}
		out = append(out, r)
	}
	return out
}

// groupTwinRuns regroupe les runs « jumeaux » multi-comptes : même instance
// (InstanceID) et fenêtres [StartedAt, EndedAt] qui se chevauchent = même
// session vécue par plusieurs personnages de la machine. Deux resets
// successifs d'une chaîne de boost ne se chevauchent jamais → jamais
// regroupés à tort. Un run encore in_progress occupe sa fenêtre jusqu'à
// maintenant (now) : il agrège — et donc DIFFÈRE — les jumeaux qui se
// terminent pendant qu'il court (les zombies sont écartés en amont par
// dropStaleRuns). L'entrée doit être triée stable ; on trie ici par
// (InstanceID, StartedAt).
func groupTwinRuns(runs []manifestRun, now int64) [][]manifestRun {
	sorted := append([]manifestRun(nil), runs...)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].InstanceID != sorted[j].InstanceID {
			return sorted[i].InstanceID < sorted[j].InstanceID
		}
		return sorted[i].StartedAt < sorted[j].StartedAt
	})
	var groups [][]manifestRun
	var end int64
	for _, r := range sorted {
		rEnd := r.EndedAt
		if r.Status != "complete" || rEnd == 0 {
			rEnd = now
		}
		if n := len(groups); n > 0 && groups[n-1][0].InstanceID == r.InstanceID && r.StartedAt <= end {
			groups[n-1] = append(groups[n-1], r)
			if rEnd > end {
				end = rEnd
			}
			continue
		}
		groups = append(groups, []manifestRun{r})
		end = rEnd
	}
	return groups
}

// processDungeonLogs consomme le manifeste de runs publié par l'addon et
// transmet, pour chaque SESSION complète non encore envoyée, le segment
// correspondant du log de combat. L'addon ne fournit que des timestamps ;
// le démon mappe la fenêtre vers une plage de lignes du log. Les runs
// jumeaux multi-comptes (fenêtres qui se chevauchent sur la même instance)
// sont regroupés : UN envoi par session, fenêtre union des points de vue —
// sans quoi chaque compte produisait son propre rapport côté serveur
// (fenêtres décalées de quelques secondes → sha distincts).
func (a *App) processDungeonLogs(ctx context.Context) error {
	runs := dropStaleRuns(a.collectManifestRuns(), time.Now().Unix())
	if len(runs) == 0 {
		return nil
	}
	year := time.Now().Year()
	for _, group := range groupTwinRuns(runs, time.Now().Unix()) {
		// Jumeaux pas encore transmis (les autres l'ont déjà été).
		pending := make([]manifestRun, 0, len(group))
		for _, r := range group {
			if !a.state.runSent(a.dedupKey(r.ID)) {
				pending = append(pending, r)
			}
		}
		if len(pending) == 0 {
			continue
		}
		// La session n'est envoyée que close et mûrie pour TOUS ses jumeaux.
		// Délai de grâce : le client WoW écrit son log par blocs bufferisés.
		// Découper un run fraîchement clos peut tronquer le segment au
		// milieu d'un bloc non encore flushé — cas réel : le UNIT_DIED du
		// dernier boss (1 ms après son ENCOUNTER_END) absent du segment au
		// Monastère, dev ET prod. La session mûrira au prochain cycle.
		ready := true
		for _, r := range group {
			if r.Status != "complete" || time.Since(time.Unix(r.EndedAt, 0)) < flushGrace {
				ready = false
				break
			}
		}
		if !ready {
			continue
		}
		// Fenêtre UNION du groupe (couvre tous les points de vue) ; le
		// run représentant (identité d'upload) est la fenêtre la plus large.
		rep := pending[0]
		start, end := rep.StartedAt, rep.EndedAt
		for _, r := range pending[1:] {
			if r.StartedAt < start {
				start = r.StartedAt
			}
			if r.EndedAt > end {
				end = r.EndedAt
			}
			if r.EndedAt-r.StartedAt > rep.EndedAt-rep.StartedAt {
				rep = r
			}
		}
		markAll := func() {
			for _, r := range pending {
				_ = a.state.markRunSent(a.dedupKey(r.ID))
			}
		}
		twins := ""
		if len(pending) > 1 {
			twins = fmt.Sprintf(" (+%d jumeau(x) multi-compte regroupé(s))", len(pending)-1)
		}
		// Le client 1.15.8+ crée un log horodaté PAR session de logging :
		// on liste à chaque passage et on ne retient que les fichiers dont
		// la plage [SessionStart, ModTime] intersecte la fenêtre de session.
		candidates := combatLogCandidates(
			discovery.ListCombatLogs(a.paths.LogsDir), start, end)
		if len(candidates) == 0 {
			a.logger.Printf("run %s : aucun log de combat ne couvre la fenêtre, ignoré%s", rep.ID, twins)
			markAll()
			continue
		}
		var (
			segment []byte
			err     error
		)
		if len(pending) == 1 && rep.ByteEnd > rep.ByteStart {
			// Bornes octets explicites (override de test/debug) : appliquées
			// au log le plus récent couvrant la fenêtre.
			segment, err = readSegment(candidates[0], rep.ByteStart, rep.ByteEnd)
		} else {
			// Parmi les candidats, on retient le segment LE PLUS RICHE :
			// en dual-box chaque client écrit son propre fichier, et les
			// points de vue divergent (le combatlog ne porte que ce qui est
			// à portée — un perso resté loin du boss produit un segment
			// appauvri, cas réel observé au Monastère écarlate).
			for _, p := range candidates {
				seg, e := segmentByTime(p, start, end, year)
				if e != nil {
					err = e
					continue
				}
				if len(seg) > len(segment) {
					segment, err = seg, nil
				}
			}
			if len(segment) > 0 {
				err = nil
			}
		}
		if err != nil {
			a.logger.Printf("run %s : lecture segment : %v", rep.ID, err)
			continue
		}
		if len(segment) == 0 {
			a.logger.Printf("run %s : segment vide, ignoré%s", rep.ID, twins)
			markAll()
			continue
		}
		name, realm := splitCharacter(rep.Character)
		meta := upload.CombatMeta{
			Realm:        realm,
			Uploader:     name,
			InstanceName: rep.Instance,
			MapID:        rep.InstanceID,
			StartedAt:    start,
			EndedAt:      end,
			Floors:       toUploadFloors(rep.Floors),
		}
		res, err := a.uploader.SendDungeonLog(ctx, meta, segment)
		if err != nil {
			if upload.IsDefinitive(err) {
				// Segment refusé (ex. format invalide) : ne pas retenter à l'identique.
				a.logger.Printf("run %s rejeté (définitif), ignoré : %v", rep.ID, err)
				markAll()
				continue
			}
			a.logger.Printf("run %s : envoi : %v", rep.ID, err)
			continue // transitoire
		}
		if res.Duplicate {
			a.logger.Printf("run donjon déjà connu côté serveur : %s (%s)%s", rep.ID, rep.Instance, twins)
		} else {
			a.logger.Printf("run donjon transmis : %s (%s, %d octets, upload #%d)%s", rep.ID, rep.Instance, len(segment), res.UploadID, twins)
		}
		markAll()
	}
	return nil
}

// splitCharacter sépare une clé "Nom-Royaume" en (nom, royaume slug minuscule).
// Le royaume vide retombe sur "auberdine" (défaut serveur).
func splitCharacter(key string) (name, realm string) {
	if i := strings.LastIndex(key, "-"); i >= 0 {
		name = key[:i]
		realm = strings.ToLower(key[i+1:])
	} else {
		name = key
	}
	if realm == "" {
		realm = "auberdine"
	}
	return name, realm
}

// readSegment lit [start, end) du log de combat. Si end <= start, lit jusqu'à la fin.
func readSegment(path string, start, end int64) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if start > 0 {
		if _, err := f.Seek(start, 0); err != nil {
			return nil, err
		}
	}
	if end > start {
		buf := make([]byte, end-start)
		n, err := io.ReadFull(f, buf)
		if err != nil && err != io.ErrUnexpectedEOF && err != io.EOF {
			return nil, err
		}
		return buf[:n], nil
	}
	return io.ReadAll(f)
}
