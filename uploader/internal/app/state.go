package app

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
)

// State est l'état technique de transmission, persisté localement. Il ne
// contient aucune donnée d'activité « métier » : uniquement de quoi éviter les
// renvois (dédup) et reprendre une lecture incrémentale de log (offsets).
type State struct {
	mu sync.Mutex

	// ExportHashes : dernier hash transmis par fichier SavedVariables.
	ExportHashes map[string]string `json:"exportHashes"`
	// CombatOffsets : position de lecture déjà traitée par fichier de log.
	CombatOffsets map[string]int64 `json:"combatOffsets"`
	// SentRuns : identifiants de runs de donjon déjà transmis (dédup).
	SentRuns map[string]bool `json:"sentRuns"`

	path string
}

func statePath() (string, error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "auberdine-uploader", "state.json"), nil
}

// LoadState lit l'état depuis le disque (valeurs vides si absent).
func LoadState() (*State, error) {
	p, err := statePath()
	if err != nil {
		return nil, err
	}
	s := &State{
		ExportHashes:  map[string]string{},
		CombatOffsets: map[string]int64{},
		SentRuns:      map[string]bool{},
		path:          p,
	}
	data, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, s); err != nil {
		return nil, err
	}
	if s.ExportHashes == nil {
		s.ExportHashes = map[string]string{}
	}
	if s.CombatOffsets == nil {
		s.CombatOffsets = map[string]int64{}
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
	return os.WriteFile(s.path, data, 0o600)
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

func (s *State) combatOffset(file string) int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.CombatOffsets[file]
}

func (s *State) setCombatOffset(file string, off int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.CombatOffsets[file] = off
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
