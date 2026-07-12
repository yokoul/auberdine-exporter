//go:build !windows && !darwin

package discovery

import (
	"os"
	"path/filepath"
)

// candidateVersionDirs renvoie les emplacements probables du dossier
// "_classic_era_" sous Linux : préfixes Wine/Lutris/Steam-Proton courants.
func candidateVersionDirs() []string {
	var roots []string
	if home, err := os.UserHomeDir(); err == nil {
		roots = append(roots,
			filepath.Join(home, "Games", "world-of-warcraft", "drive_c", "Program Files (x86)", "World of Warcraft"),
			filepath.Join(home, ".wine", "drive_c", "Program Files (x86)", "World of Warcraft"),
			filepath.Join(home, ".local", "share", "lutris", "runners"),
		)
	}
	return versionDirsFromRoots(roots)
}
