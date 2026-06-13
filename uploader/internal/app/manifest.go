package app

import (
	"os"
	"strconv"
	"strings"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// floorSample est un relevé d'étage capté par l'addon (C_Map) : t = epoch s,
// m = uiMapID de l'étage courant, x/y = position normalisée [0,1] sur cet
// étage. Sert au replay à choisir le bon plan dans les donjons verticaux où
// le log de combat ne porte pas l'étage (uiMapID = 0 en Era).
type floorSample struct {
	T int64   `json:"t"`
	M int64   `json:"m"`
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

// manifestRun reflète une entrée de uploaderManifest.runs publiée par l'addon
// (voir docs/UPLOADER-ARCHITECTURE.md §6). Les champs sont tolérants : le
// manifeste vient d'une table Lua, les nombres y sont des float64.
type manifestRun struct {
	ID         string
	Instance   string
	InstanceID int64
	Character  string
	StartedAt  int64
	EndedAt    int64
	ByteStart  int64
	ByteEnd    int64
	Status     string
	Floors     []floorSample
}

// collectManifestRuns parcourt toutes les SavedVariables connues et agrège les
// runs déclarés dans uploaderManifest. C'est l'addon qui détient l'intelligence
// du découpage ; le démon ne fait que consommer ce qu'il publie.
func (a *App) collectManifestRuns() []manifestRun {
	var out []manifestRun
	for _, sv := range a.paths.SavedVars {
		raw, err := os.ReadFile(sv)
		if err != nil {
			continue
		}
		parsed, err := luasv.Parse(string(raw))
		if err != nil {
			continue
		}
		db, ok := parsed["AuberdineExporterDB"].(map[string]any)
		if !ok {
			continue
		}
		man, ok := db["uploaderManifest"].(map[string]any)
		if !ok {
			continue
		}
		runs, ok := man["runs"].([]any)
		if !ok {
			continue
		}
		for _, r := range runs {
			m, ok := r.(map[string]any)
			if !ok {
				continue
			}
			out = append(out, manifestRun{
				ID:         asString(m["id"]),
				Instance:   asString(m["instance"]),
				InstanceID: asInt64(m["instanceId"]),
				Character:  asString(m["character"]),
				StartedAt:  asInt64(m["startedAt"]),
				EndedAt:    asInt64(m["endedAt"]),
				ByteStart:  asInt64(m["byteStart"]),
				ByteEnd:    asInt64(m["byteEnd"]),
				Status:     asString(m["status"]),
				Floors:     parseFloors(m["floors"]),
			})
		}
	}
	return out
}

// parseFloors convertit la table Lua floors[] (liste de { t, m, x, y }) en
// []floorSample. Tolérant aux types numériques du parseur Lua.
func parseFloors(v any) []floorSample {
	arr, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]floorSample, 0, len(arr))
	for _, e := range arr {
		m, ok := e.(map[string]any)
		if !ok {
			continue
		}
		out = append(out, floorSample{
			T: asInt64(m["t"]),
			M: asInt64(m["m"]),
			X: asFloat64(m["x"]),
			Y: asFloat64(m["y"]),
		})
	}
	return out
}

// toUploadFloors convertit les relevés internes en type de transport.
func toUploadFloors(in []floorSample) []upload.FloorSample {
	if len(in) == 0 {
		return nil
	}
	out := make([]upload.FloorSample, len(in))
	for i, f := range in {
		out[i] = upload.FloorSample{T: f.T, M: f.M, X: f.X, Y: f.Y}
	}
	return out
}

func asString(v any) string {
	s, _ := v.(string)
	return s
}

// asFloat64 tolère les types numériques du parseur Lua.
func asFloat64(v any) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case int64:
		return float64(n)
	case int:
		return float64(n)
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(n), 64)
		return f
	default:
		return 0
	}
}

// asInt64 tolère les types numériques que peut produire le parseur Lua selon
// que la valeur est un entier ou un flottant (int, int64, float64), ainsi qu'une
// éventuelle chaîne numérique.
func asInt64(v any) int64 {
	switch n := v.(type) {
	case int64:
		return n
	case int:
		return int64(n)
	case float64:
		return int64(n)
	case string:
		i, _ := strconv.ParseInt(strings.TrimSpace(n), 10, 64)
		return i
	default:
		return 0
	}
}
