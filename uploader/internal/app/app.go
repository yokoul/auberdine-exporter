// Package app assemble le démon : découverte des fichiers, surveillance par
// polling léger, transmission des exports et des segments de log de donjon.
package app

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync/atomic"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// App est le démon de l'uploader.
type App struct {
	cfg      config.Config
	paths    discovery.Paths
	state    *State
	uploader upload.Uploader
	logger   *log.Logger

	paused atomic.Bool
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
	if up == nil {
		up = upload.NewHTTP(cfg.Endpoint,
			func() string { return cfg.Discord.AccessToken },
			func() string { return cfg.Discord.UserID },
		)
	}
	if logger == nil {
		logger = log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	}
	return &App{cfg: cfg, paths: paths, state: st, uploader: up, logger: logger}, nil
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
	interval := time.Duration(a.cfg.PollIntervalSeconds) * time.Second
	if interval <= 0 {
		interval = 5 * time.Second
	}
	a.logger.Printf("démarrage : %d SavedVariables, log=%s", len(a.paths.SavedVars), a.paths.CombatLog)

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

// tick effectue un cycle de surveillance.
func (a *App) tick(ctx context.Context) {
	if a.paused.Load() {
		return
	}
	if a.cfg.UploadExports {
		for _, sv := range a.paths.SavedVars {
			if err := a.processExport(ctx, sv); err != nil {
				a.logger.Printf("export %s : %v", sv, err)
			}
		}
	}
	if a.cfg.UploadDungeonLogs {
		if err := a.processDungeonLogs(ctx); err != nil {
			a.logger.Printf("logs donjon : %v", err)
		}
	}
}

// processExport lit une SavedVariable, en extrait la base de l'addon et la
// transmet si son contenu a changé depuis le dernier envoi.
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
		// Fichier présent mais sans données de l'addon : rien à faire.
		return nil
	}

	payload, err := json.Marshal(db)
	if err != nil {
		return err
	}
	sum := sha256.Sum256(payload)
	hash := hex.EncodeToString(sum[:])
	if hash == a.state.lastExportHash(svPath) {
		return nil // inchangé : dédup
	}

	accountKey, _ := db["accountKey"].(string)
	if err := a.uploader.SendExport(ctx, accountKey, payload); err != nil {
		return err
	}
	a.logger.Printf("export transmis (%d octets) depuis %s", len(payload), svPath)
	return a.state.setExportHash(svPath, hash)
}

// processDungeonLogs lit, de façon incrémentale, le manifeste de runs publié
// par l'addon dans la SavedVariable et transmet pour chaque nouveau run le
// segment brut correspondant du log de combat.
//
// Tant que l'addon ne publie pas de manifeste (uploaderManifest), aucun segment
// n'est transmis : repli sûr, on n'envoie jamais un log à l'aveugle.
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
		// Bornes en octets explicites (override de test/debug) sinon
		// segmentation par fenêtre temporelle — l'addon ne fournit que des
		// timestamps, pas d'offsets.
		var (
			segment []byte
			err     error
		)
		if r.ByteEnd > r.ByteStart {
			segment, err = readSegment(a.paths.CombatLog, r.ByteStart, r.ByteEnd)
		} else {
			segment, err = segmentByTime(a.paths.CombatLog, r.StartedAt, r.EndedAt, year)
		}
		if err != nil {
			a.logger.Printf("run %s : lecture segment : %v", r.ID, err)
			continue
		}
		if len(segment) == 0 {
			// Aucune ligne dans la fenêtre : on n'envoie pas un segment vide,
			// mais on ne re-scanne pas indéfiniment.
			a.logger.Printf("run %s : segment vide, ignoré", r.ID)
			a.state.markRunSent(r.ID)
			continue
		}
		meta := upload.DungeonMeta{
			RunID:     r.ID,
			Instance:  r.Instance,
			Character: r.Character,
			StartedAt: r.StartedAt,
			EndedAt:   r.EndedAt,
		}
		if err := a.uploader.SendDungeonLog(ctx, meta, segment); err != nil {
			a.logger.Printf("run %s : envoi : %v", r.ID, err)
			continue
		}
		a.logger.Printf("run donjon transmis : %s (%s, %d octets)", r.ID, r.Instance, len(segment))
		if err := a.state.markRunSent(r.ID); err != nil {
			return err
		}
	}
	return nil
}

// readSegment lit [start, end) du log de combat. Si end <= 0, lit jusqu'à la fin.
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
		n, err := f.Read(buf)
		if err != nil && n == 0 {
			return nil, err
		}
		return buf[:n], nil
	}
	// Pas de borne de fin : lit le reste.
	rest := make([]byte, 0, 64*1024)
	tmp := make([]byte, 32*1024)
	for {
		n, err := f.Read(tmp)
		rest = append(rest, tmp[:n]...)
		if err != nil {
			break
		}
	}
	return rest, nil
}
