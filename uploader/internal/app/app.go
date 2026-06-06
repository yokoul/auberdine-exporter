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
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

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
	a.logger.Printf("démarrage : %d SavedVariables, logs=%s (%d log(s) de combat présents)",
		len(a.paths.SavedVars), a.paths.LogsDir, len(discovery.ListCombatLogs(a.paths.LogsDir)))
	a.handshake(ctx)

	// Premier passage immédiat, puis à intervalle régulier.
	a.tick(ctx)
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-t.C:
			a.tick(ctx)
		}
	}
}

// handshake valide la clé API au démarrage et signale les anomalies de config
// (clé absente/invalide, compte Discord non lié). Non bloquant.
func (a *App) handshake(ctx context.Context) {
	if a.APIKey() == "" {
		a.logger.Print("⚠ clé API non configurée : aucun envoi tant que apiKey est vide (voir config.json)")
		return
	}
	st, err := a.uploader.Status(ctx)
	if err != nil {
		a.logger.Printf("⚠ handshake /ingest/status : %v", err)
		return
	}
	if !st.Partner.LinkedDiscord {
		a.logger.Print("⚠ clé API sans Discord lié : les imports passeront mais aucun personnage ne sera auto-claim")
	}
	a.logger.Printf("connecté à l'API d'ingestion (contrat v%d, clé « %s »)", st.ContractVersion, st.Partner.Label)
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
	if hash == a.state.lastExportHash(svPath) {
		return nil // inchangé : dédup
	}

	res, err := a.uploader.SendExport(ctx, payload)
	if err != nil {
		if upload.IsDefinitive(err) {
			// Payload refusé (ex. signature invalide) : inutile de le renvoyer
			// à l'identique à chaque cycle. On mémorise le hash pour ne réessayer
			// qu'au prochain export régénéré par l'addon.
			a.logger.Printf("export %s rejeté (définitif), ignoré jusqu'au prochain export : %v", svPath, err)
			return a.state.setExportHash(svPath, hash)
		}
		return err // transitoire : on réessaiera au prochain cycle
	}
	a.logger.Printf("export transmis depuis %s (%d personnage(s))", svPath, res.Processed)
	return a.state.setExportHash(svPath, hash)
}

// processDungeonLogs consomme le manifeste de runs publié par l'addon et
// transmet, pour chaque run complet non encore envoyé, le segment correspondant
// du log de combat. L'addon ne fournit que des timestamps ; le démon mappe la
// fenêtre vers une plage de lignes du log.
func (a *App) processDungeonLogs(ctx context.Context) error {
	runs := a.collectManifestRuns()
	if len(runs) == 0 {
		return nil
	}
	year := time.Now().Year()
	for _, r := range runs {
		if r.Status != "complete" || a.state.runSent(r.ID) {
			continue
		}
		// Le client 1.15.8+ crée un log horodaté PAR session de logging :
		// on liste à chaque passage et on ne retient que les fichiers dont
		// la plage [SessionStart, ModTime] intersecte la fenêtre du run.
		candidates := combatLogCandidates(
			discovery.ListCombatLogs(a.paths.LogsDir), r.StartedAt, r.EndedAt)
		if len(candidates) == 0 {
			a.logger.Printf("run %s : aucun log de combat ne couvre la fenêtre, ignoré", r.ID)
			a.state.markRunSent(r.ID)
			continue
		}
		var (
			segment []byte
			err     error
		)
		if r.ByteEnd > r.ByteStart {
			// Bornes octets explicites (override de test/debug) : appliquées
			// au log le plus récent couvrant la fenêtre.
			segment, err = readSegment(candidates[0], r.ByteStart, r.ByteEnd)
		} else {
			// Premier candidat (du plus récent au plus ancien) qui produit
			// un segment non vide — en dual-box chaque client écrit son
			// propre fichier, n'importe quel point de vue du groupe couvre
			// le run (le log contient tous les membres).
			for _, p := range candidates {
				segment, err = segmentByTime(p, r.StartedAt, r.EndedAt, year)
				if err == nil && len(segment) > 0 {
					break
				}
			}
		}
		if err != nil {
			a.logger.Printf("run %s : lecture segment : %v", r.ID, err)
			continue
		}
		if len(segment) == 0 {
			a.logger.Printf("run %s : segment vide, ignoré", r.ID)
			a.state.markRunSent(r.ID)
			continue
		}
		name, realm := splitCharacter(r.Character)
		meta := upload.CombatMeta{
			Realm:        realm,
			Uploader:     name,
			InstanceName: r.Instance,
			MapID:        r.InstanceID,
			StartedAt:    r.StartedAt,
			EndedAt:      r.EndedAt,
		}
		res, err := a.uploader.SendDungeonLog(ctx, meta, segment)
		if err != nil {
			if upload.IsDefinitive(err) {
				// Segment refusé (ex. format invalide) : ne pas retenter à l'identique.
				a.logger.Printf("run %s rejeté (définitif), ignoré : %v", r.ID, err)
				a.state.markRunSent(r.ID)
				continue
			}
			a.logger.Printf("run %s : envoi : %v", r.ID, err)
			continue // transitoire
		}
		if res.Duplicate {
			a.logger.Printf("run donjon déjà connu côté serveur : %s (%s)", r.ID, r.Instance)
		} else {
			a.logger.Printf("run donjon transmis : %s (%s, %d octets, upload #%d)", r.ID, r.Instance, len(segment), res.UploadID)
		}
		if err := a.state.markRunSent(r.ID); err != nil {
			return err
		}
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
