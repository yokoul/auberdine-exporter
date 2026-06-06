package app

import (
	"os"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
)

// manifestRun reflète une entrée de uploaderManifest.runs publiée par l'addon
// (voir docs/UPLOADER-ARCHITECTURE.md §6). Les champs sont tolérants : le
// manifeste vient d'une table Lua, les nombres y sont des float64.
type manifestRun struct {
	ID        string
	Instance  string
	Character string
	StartedAt int64
	EndedAt   int64
	ByteStart int64
	ByteEnd   int64
	Status    string
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
				ID:        asString(m["id"]),
				Instance:  asString(m["instance"]),
				Character: asString(m["character"]),
				StartedAt: asInt64(m["startedAt"]),
				EndedAt:   asInt64(m["endedAt"]),
				ByteStart: asInt64(m["byteStart"]),
				ByteEnd:   asInt64(m["byteEnd"]),
				Status:    asString(m["status"]),
			})
		}
	}
	return out
}

func asString(v any) string {
	s, _ := v.(string)
	return s
}

func asInt64(v any) int64 {
	if f, ok := v.(float64); ok {
		return int64(f)
	}
	return 0
}
