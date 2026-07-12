//go:build darwin

package discovery

import (
	"os"
	"path/filepath"
)

// candidateVersionDirs renvoie les emplacements probables du dossier
// "_classic_era_" sous macOS.
func candidateVersionDirs() []string {
	roots := []string{
		"/Applications/World of Warcraft",
	}
	if home, err := os.UserHomeDir(); err == nil {
		roots = append(roots, filepath.Join(home, "Applications", "World of Warcraft"))
	}
	return versionDirsFromRoots(roots)
}
