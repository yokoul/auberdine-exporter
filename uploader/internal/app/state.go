package app

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"

	"github.com/yokoul/auberdine-exporter/uploader/internal/atomicfile"
)

// State est l'état technique de transmission, persisté localement. Il ne
// contient aucune donnée d'activité « métier » : uniquement de quoi éviter les
// renvois (dédup) et reprendre une lecture incrémentale de log (offsets).
type State struct {
	mu sync.Mutex

	// ExportHashes : dernier hash transmis par fichier SavedVariables.
	ExportHashes map[string]string `json:"exportHashes"`
	// SentRuns : identifiants de runs de donjon déjà transmis (dédup).
	SentRuns map[string]bool `json:"sentRuns"`

	path string
}

// StateDirEnv permet de surcharger le répertoire d'état (utile en tests et en
// ops : os.UserCacheDir() n'honore pas XDG_CACHE_HOME sur macOS/Windows).
const StateDirEnv = "AUBERDINE_UPLOADER_STATE_DIR"

func statePath() (string, error) {
	dir := os.Getenv(StateDirEnv)
	if dir == "" {
		var err error
		dir, err = os.UserCacheDir()
		if err != nil {
			return "", err
		}
		dir = filepath.Join(dir, "auberdine-uploader")
	}
	return filepath.Join(dir, "state.json"), nil
}

// LoadState lit l'état depuis le disque (valeurs vides si absent).
func LoadState() (*State, error) {
	p, err := statePath()
	if err != nil {
		return nil, err
	}
	s := &State{
		ExportHashes: map[string]string{},
		SentRuns:     map[string]bool{},
		path:         p,
	}
	data, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, s); err != nil {
		// État corrompu — typiquement une écriture interrompue par un arrêt
		// brutal (l'ancien os.WriteFile tronquait avant d'écrire). NON FATAL :
		// on écarte le fichier abîmé (conservé en .corrupt pour diagnostic) et
		// on repart d'un état vide, plutôt que d'empêcher TOUT démarrage du
		// client. L'état n'est qu'un cache de dédup : le perdre ne fait que
		// renvoyer quelques données déjà transmises, sans dommage.
		_ = os.Rename(p, p+".corrupt")
		return &State{
			ExportHashes: map[string]string{},
			SentRuns:     map[string]bool{},
			path:         p,
		}, nil
	}
	if s.ExportHashes == nil {
		s.ExportHashes = map[string]string{}
	}
	if s.SentRuns == nil {
		s.SentRuns = map[string]bool{}
	}
	s.path = p
	return s, nil
}

func (s *State) save() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return atomicfile.Write(s.path, data, 0o600)
}

func (s *State) lastExportHash(file string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.ExportHashes[file]
}

func (s *State) setExportHash(file, hash string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ExportHashes[file] = hash
	return s.save()
}

func (s *State) runSent(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.SentRuns[id]
}

func (s *State) markRunSent(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.SentRuns[id] = true
	return s.save()
}
