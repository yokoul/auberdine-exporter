// Package discovery localise l'installation de WoW Classic Era ainsi que les
// fichiers consommés par l'uploader : la SavedVariable de l'addon et le log de
// combat. La détection est best-effort par OS, toujours surchargeable via la
// configuration (champ WoWPath).
package discovery

import (
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"time"
)

// SavedVarFile est le nom du fichier SavedVariables de l'addon.
const SavedVarFile = "AuberdineExporter.lua"

// Paths regroupe les chemins résolus pour une installation WoW.
type Paths struct {
	// VersionDir est le dossier de version (ex. ".../_classic_era_").
	VersionDir string
	// LogsDir est le dossier des logs du client (Logs/). Les fichiers de
	// combat eux-mêmes sont listés à la demande par ListCombatLogs : le
	// client moderne (1.15.8+) crée UN fichier horodaté PAR session de
	// logging (WoWCombatLog-MMJJAA_HHMMSS.txt) — la liste change donc en
	// cours de vie du démon, on ne peut pas la figer au démarrage.
	LogsDir string
	// SavedVars liste tous les AuberdineExporter.lua trouvés (multi-compte).
	SavedVars []string
}

// CombatLogInfo décrit un fichier de log de combat présent sur disque.
type CombatLogInfo struct {
	Path string
	// SessionStart est l'horodatage du nom de fichier (début de la session
	// de logging) — zéro pour le legacy WoWCombatLog.txt sans horodatage.
	SessionStart time.Time
	// ModTime borne la fin de la plage couverte par le fichier.
	ModTime time.Time
}

// combatLogNameRe matche le legacy "WoWCombatLog.txt" et les fichiers par
// session "WoWCombatLog-MMJJAA_HHMMSS.txt" (client 1.15.8+).
var combatLogNameRe = regexp.MustCompile(`^WoWCombatLog(?:-(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2}))?\.txt$`)

// ListCombatLogs liste les logs de combat du dossier Logs/, du plus récent au
// plus ancien (SessionStart décroissant, legacy sans horodatage en dernier).
func ListCombatLogs(logsDir string) []CombatLogInfo {
	entries, err := os.ReadDir(logsDir)
	if err != nil {
		return nil
	}
	var out []CombatLogInfo
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		m := combatLogNameRe.FindStringSubmatch(e.Name())
		if m == nil {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		cl := CombatLogInfo{
			Path:    filepath.Join(logsDir, e.Name()),
			ModTime: info.ModTime(),
		}
		if m[1] != "" {
			// MMJJAA_HHMMSS, heure locale (cohérente avec le time() Lua de
			// l'addon : même machine que le client).
			cl.SessionStart = time.Date(
				2000+atoi2(m[3]), time.Month(atoi2(m[1])), atoi2(m[2]),
				atoi2(m[4]), atoi2(m[5]), atoi2(m[6]), 0, time.Local)
		}
		out = append(out, cl)
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].SessionStart.After(out[j].SessionStart)
	})
	return out
}

func atoi2(s string) int {
	n := 0
	for _, c := range s {
		n = n*10 + int(c-'0')
	}
	return n
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
		LogsDir:    filepath.Join(versionDir, "Logs"),
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
