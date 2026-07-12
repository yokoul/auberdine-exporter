//go:build windows

package discovery

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/sys/windows/registry"
)

// candidateVersionDirs renvoie les emplacements probables du dossier
// "_classic_era_" sous Windows. Au-delà des chemins classiques sur C:, une
// installation peut vivre sur n'importe quel disque (le cas réel qui a motivé
// cet élargissement) : on interroge donc aussi le registre, le product.db de
// l'agent Battle.net, puis on balaye les dossiers usuels de chaque lecteur.
func candidateVersionDirs() []string {
	roots := []string{
		`C:\Program Files (x86)\World of Warcraft`,
		`C:\Program Files\World of Warcraft`,
		`C:\World of Warcraft`,
	}
	roots = append(roots, registryRoots()...)
	roots = append(roots, productDBRoots()...)
	roots = append(roots, driveScanRoots()...)
	return versionDirsFromRoots(roots)
}

// registryRoots lit les emplacements d'installation que Battle.net enregistre
// dans le registre. Best-effort : toute clé absente est simplement ignorée.
func registryRoots() []string {
	specs := []struct {
		path  string
		value string
	}{
		// Entrée de désinstallation posée par Battle.net pour Classic Era
		// (InstallLocation = racine "World of Warcraft").
		{`SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft Classic Era`, "InstallLocation"},
		{`SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft Classic Era`, "InstallLocation"},
		// Clé historique Blizzard (InstallPath pointe parfois sur un dossier
		// de version comme _retail_ — normalizeRoot remonte à la racine).
		{`SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft`, "InstallPath"},
		{`SOFTWARE\Blizzard Entertainment\World of Warcraft`, "InstallPath"},
	}
	var out []string
	for _, s := range specs {
		k, err := registry.OpenKey(registry.LOCAL_MACHINE, s.path, registry.QUERY_VALUE)
		if err != nil {
			continue
		}
		v, _, err := k.GetStringValue(s.value)
		k.Close()
		if err != nil || v == "" {
			continue
		}
		out = append(out, normalizeRoot(v))
	}
	return out
}

// productDBPathRe extrait d'un contenu binaire les chemins d'installation se
// terminant par "World of Warcraft" (forward ou back slashes, lettre de
// lecteur en tête).
var productDBPathRe = regexp.MustCompile(`[A-Za-z]:[/\\][^\x00-\x1f"|<>*?]*?World of Warcraft`)

// productDBRoots extrait les racines WoW du product.db de l'agent Battle.net.
// Le fichier est du protobuf binaire, mais les chemins d'installation y
// figurent en clair : c'est la source la plus fiable pour une installation
// hors des emplacements standards, puisqu'elle reflète le dossier réellement
// choisi dans Battle.net, quel que soit le disque.
func productDBRoots() []string {
	programData := os.Getenv("ProgramData")
	if programData == "" {
		programData = `C:\ProgramData`
	}
	p := filepath.Join(programData, "Battle.net", "Agent", "product.db")
	fi, err := os.Stat(p)
	if err != nil || fi.Size() > 1<<20 {
		return nil
	}
	data, err := os.ReadFile(p)
	if err != nil {
		return nil
	}
	return productDBRootsFrom(data)
}

// productDBRootsFrom isole l'extraction pour les tests (pas de product.db sur
// une machine de CI).
func productDBRootsFrom(data []byte) []string {
	var out []string
	for _, m := range productDBPathRe.FindAll(data, -1) {
		out = append(out, filepath.FromSlash(string(m)))
	}
	return out
}

// driveScanRoots balaye les lecteurs C: à Z: sur les dossiers d'installation
// usuels. Un stat par lecteur puis six par lecteur présent : négligeable au
// démarrage, et c'est le filet qui rattrape un WoW déplacé à la main.
func driveScanRoots() []string {
	subdirs := []string{
		`World of Warcraft`,
		`Games\World of Warcraft`,
		`Jeux\World of Warcraft`,
		`Blizzard\World of Warcraft`,
		`Program Files (x86)\World of Warcraft`,
		`Program Files\World of Warcraft`,
	}
	var out []string
	for d := 'C'; d <= 'Z'; d++ {
		drive := string(d) + `:\`
		if _, err := os.Stat(drive); err != nil {
			continue
		}
		for _, s := range subdirs {
			out = append(out, drive+s)
		}
	}
	return out
}

// normalizeRoot ramène un chemin de registre à la racine WoW : si la valeur
// pointe sur un dossier de version ("..._retail_", "..._classic_era_"), on
// remonte au parent — versionDirsFromRoots rajoutera le bon dossier.
func normalizeRoot(p string) string {
	p = filepath.Clean(p)
	if base := filepath.Base(p); strings.HasPrefix(base, "_") && strings.HasSuffix(base, "_") {
		return filepath.Dir(p)
	}
	return p
}
