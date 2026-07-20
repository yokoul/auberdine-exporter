package app

import (
	"context"
	"fmt"
	"os"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// meshSightingSpec décrit une liste d'observations du mesh addon (Comms.lua)
// à relayer vers le serveur : quelle SavedVariable lire, vers quel endpoint
// pousser, et quels champs embarquer. Les worldbuffs (kind S) gardent leur
// sync historique typé (syncWorldbuffSightings) ; les kinds suivants passent
// par ce chemin générique — en ajouter un = ajouter une entrée ici.
type meshSightingSpec struct {
	savedVar  string   // liste dans AuberdineExporterDB
	path      string   // POST /ingest/<path>/sightings
	statePfx  string   // namespace des clés de dédup (state.json, SentSightings)
	idField   string   // identifiant numérique du sujet (npcId / encounterId)
	strFields []string // champs texte optionnels, copiés tels quels
	numFields []string // champs numériques optionnels
}

var meshSightingSpecs = []meshSightingSpec{
	{
		// Morts de world bosses (WorldbossLogger.lua, mesh kind W).
		savedVar:  "worldbossSightings",
		path:      "worldbosses",
		statePfx:  "wboss",
		idField:   "npcId",
		strFields: []string{"name", "guild", "faction", "zone"},
	},
	{
		// Boss de raid vaincus (KillLogger.lua, mesh kind K).
		savedVar:  "raidkillSightings",
		path:      "raidkills",
		statePfx:  "kill",
		idField:   "encounterId",
		strFields: []string{"name", "guild", "faction"},
		numFields: []string{"instanceId"},
	},
}

// syncMeshSightings relaie les voies montantes du mesh (hors worldbuffs) :
// mêmes règles que syncWorldbuffSightings — dédup locale par clé stable dans
// le state, lot borné, erreurs définitives marquées transmises pour ne pas
// boucler dessus.
func (a *App) syncMeshSightings(ctx context.Context) {
	if a.APIKey() == "" {
		return
	}
	for _, spec := range meshSightingSpecs {
		a.syncOneMeshList(ctx, spec)
	}
}

func (a *App) syncOneMeshList(ctx context.Context, spec meshSightingSpec) {
	var batch []map[string]any
	var keys []string
	for _, p := range a.paths.SavedVars {
		raw, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		parsed, err := luasv.Parse(string(raw))
		if err != nil {
			continue
		}
		db, _ := parsed["AuberdineExporterDB"].(map[string]any)
		list, _ := db[spec.savedVar].([]any)
		for _, it := range list {
			s, ok := it.(map[string]any)
			if !ok {
				continue
			}
			id, _ := s[spec.idField].(float64)
			at, _ := s["at"].(float64)
			character, _ := s["character"].(string)
			realm, _ := s["realm"].(string)
			if id == 0 || at == 0 || character == "" || realm == "" {
				continue
			}
			key := fmt.Sprintf("%s|%s|%s|%d|%d", spec.statePfx, realm, character, int64(id), int64(at))
			if a.state.sightingSent(key) {
				continue
			}
			entry := map[string]any{
				spec.idField: int64(id),
				"at":         int64(at),
				"character":  character,
				"realm":      realm,
			}
			for _, f := range spec.strFields {
				if v, _ := s[f].(string); v != "" {
					entry[f] = v
				}
			}
			for _, f := range spec.numFields {
				if v, _ := s[f].(float64); v != 0 {
					entry[f] = int64(v)
				}
			}
			if rel, _ := s["relayed"].(bool); rel {
				entry["relayed"] = true
			}
			batch = append(batch, entry)
			keys = append(keys, key)
			if len(batch) >= sightingsBatchMax {
				break
			}
		}
	}
	if len(batch) == 0 {
		return
	}
	stored, err := a.uploader.SendMeshSightings(ctx, spec.path, batch)
	if err != nil {
		if upload.IsDefinitive(err) {
			// Contenu refusé : marquer transmis pour ne pas boucler dessus.
			_ = a.state.markSightingsSent(keys)
		}
		return // transitoire / endpoint absent (vieux serveur) : on retentera
	}
	if err := a.state.markSightingsSent(keys); err != nil {
		a.logger.Printf("%s state : %v", spec.path, err)
	}
	a.logger.Printf("%s : %d observation(s) transmise(s) (%d retenue(s) serveur)", spec.path, len(batch), stored)
}
