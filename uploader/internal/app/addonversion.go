// Vérification de la version de l'addon — le journal de combat de donjon
// (DungeonLogger + manifeste) n'existe qu'à partir de 1.7.0. En-deçà, les
// exports fonctionnent mais aucun run de donjon ne sera jamais balisé : on
// le dit clairement plutôt que de laisser l'utilisateur attendre des
// chroniques qui ne viendront pas.
package app

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
)

// MinDungeonAddonVersion est la première version de l'addon embarquant le
// DungeonLogger.
const MinDungeonAddonVersion = "1.7.0"

// versionLess compare deux versions numériques "a.b.c" segment par segment.
// Les segments non numériques valent zéro ; les longueurs inégales sont
// complétées ("1.7" == "1.7.0").
func versionLess(a, b string) bool {
	as, bs := strings.Split(a, "."), strings.Split(b, ".")
	for i := 0; i < len(as) || i < len(bs); i++ {
		var av, bv int
		if i < len(as) {
			av, _ = strconv.Atoi(strings.TrimSpace(as[i]))
		}
		if i < len(bs) {
			bv, _ = strconv.Atoi(strings.TrimSpace(bs[i]))
		}
		if av != bv {
			return av < bv
		}
	}
	return false
}

// checkAddonVersion avertit — une fois par démarrage et par version vue —
// quand l'addon d'un compte est antérieur au journal de donjon.
func (a *App) checkAddonVersion(svPath string, db map[string]any) {
	version, _ := db["version"].(string)
	if version == "" || !versionLess(version, MinDungeonAddonVersion) {
		return
	}
	key := svPath + "@" + version
	a.mu.Lock()
	if a.addonWarned == nil {
		a.addonWarned = make(map[string]bool)
	}
	seen := a.addonWarned[key]
	a.addonWarned[key] = true
	a.mu.Unlock()
	if seen {
		return
	}
	a.logger.Printf("⚠ addon %s détecté (%s) : le journal de donjon nécessite %s+ — mettez à jour AuberdineExporter puis redémarrez complètement le client", version, svPath, MinDungeonAddonVersion)
}

// ReadAddonVersion lit la version de l'addon dans une SavedVariable —
// utilisé par `doctor`. Renvoie "" si illisible.
func ReadAddonVersion(svPath string) string {
	raw, err := os.ReadFile(svPath)
	if err != nil {
		return ""
	}
	parsed, err := luasv.Parse(string(raw))
	if err != nil {
		return ""
	}
	db, ok := parsed["AuberdineExporterDB"].(map[string]any)
	if !ok {
		return ""
	}
	v, _ := db["version"].(string)
	return v
}

// AddonVersionVerdict renvoie une ligne de diagnostic pour `doctor`.
func AddonVersionVerdict(svPath string) string {
	v := ReadAddonVersion(svPath)
	switch {
	case v == "":
		return "version addon inconnue (export jamais écrit ?)"
	case versionLess(v, MinDungeonAddonVersion):
		return fmt.Sprintf("addon %s — journal de donjon INDISPONIBLE (requiert %s+)", v, MinDungeonAddonVersion)
	default:
		return fmt.Sprintf("addon %s — journal de donjon disponible", v)
	}
}
