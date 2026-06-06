// Package discovery localise l'installation de WoW Classic Era ainsi que les
// fichiers consommés par l'uploader : la SavedVariable de l'addon et le log de
// combat. La détection est best-effort par OS, toujours surchargeable via la
// configuration (champ WoWPath).
package discovery

import (
	"os"
	"path/filepath"
	"runtime"
)

// SavedVarFile est le nom du fichier SavedVariables de l'addon.
const SavedVarFile = "AuberdineExporter.lua"

// CombatLogFile est le nom du log de combat écrit par le client WoW.
const CombatLogFile = "WoWCombatLog.txt"

// Paths regroupe les chemins résolus pour une installation WoW.
type Paths struct {
	// VersionDir est le dossier de version (ex. ".../_classic_era_").
	VersionDir string
	// CombatLog est le chemin attendu du log de combat.
	CombatLog string
	// SavedVars liste tous les AuberdineExporter.lua trouvés (multi-compte).
	SavedVars []string
}

// candidateVersionDirs renvoie les emplacements probables du dossier
// "_classic_era_" selon l'OS.
func candidateVersionDirs() []string {
	var roots []string
	switch runtime.GOOS {
	case "windows":
		for _, base := range []string{
			`C:\Program Files (x86)\World of Warcraft`,
			`C:\Program Files\World of Warcraft`,
			`C:\World of Warcraft`,
		} {
			roots = append(roots, base)
		}
	case "darwin":
		roots = append(roots,
			"/Applications/World of Warcraft",
		)
		if home, err := os.UserHomeDir(); err == nil {
			roots = append(roots, filepath.Join(home, "Applications", "World of Warcraft"))
		}
	default: // linux : préfixes Wine/Lutris/Steam-Proton courants
		if home, err := os.UserHomeDir(); err == nil {
			roots = append(roots,
				filepath.Join(home, "Games", "world-of-warcraft", "drive_c", "Program Files (x86)", "World of Warcraft"),
				filepath.Join(home, ".wine", "drive_c", "Program Files (x86)", "World of Warcraft"),
				filepath.Join(home, ".local", "share", "lutris", "runners"),
			)
		}
	}

	var out []string
	for _, r := range roots {
		out = append(out, filepath.Join(r, "_classic_era_"))
	}
	return out
}

// Detect tente de localiser l'installation. Si override est non vide, il est
// utilisé tel quel comme dossier de version.
func Detect(override string) (Paths, bool) {
	if override != "" {
		return resolve(override), true
	}
	for _, dir := range candidateVersionDirs() {
		if isDir(dir) {
			return resolve(dir), true
		}
	}
	return Paths{}, false
}

// resolve construit les chemins dérivés à partir du dossier de version.
func resolve(versionDir string) Paths {
	return Paths{
		VersionDir: versionDir,
		CombatLog:  filepath.Join(versionDir, "Logs", CombatLogFile),
		SavedVars:  findSavedVars(versionDir),
	}
}

// findSavedVars parcourt WTF/Account/<COMPTE>/SavedVariables/ pour collecter
// tous les AuberdineExporter.lua (un par compte WoW).
func findSavedVars(versionDir string) []string {
	accountDir := filepath.Join(versionDir, "WTF", "Account")
	entries, err := os.ReadDir(accountDir)
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		p := filepath.Join(accountDir, e.Name(), "SavedVariables", SavedVarFile)
		if fileExists(p) {
			out = append(out, p)
		}
	}
	return out
}

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}

func fileExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && !fi.IsDir()
}
