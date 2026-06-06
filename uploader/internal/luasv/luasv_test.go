package luasv

import (
	"reflect"
	"testing"
)

func TestParseSavedVariables(t *testing.T) {
	// Échantillon représentatif d'une SavedVariable AuberdineExporter :
	// variable globale, sous-tables map et tableau, clés quotées et entières,
	// types mixtes, commentaire.
	src := `
-- AuberdineExporter saved variables
AuberdineExporterDB = {
	["version"] = "1.6.4",
	["accountKey"] = "abc-123",
	["characters"] = {
		["Carnalis-Auberdine"] = {
			["name"] = "Carnalis",
			["level"] = 60,
			["money"] = 123456,
			["completedQuests"] = {
				["123"] = 1733500000,
				["456"] = 1733500100,
			},
			["skills"] = {
				"Cooking",
				"First Aid",
			},
			["enabled"] = true,
		},
	},
}
`
	got, err := Parse(src)
	if err != nil {
		t.Fatalf("Parse a échoué: %v", err)
	}

	db, ok := got["AuberdineExporterDB"].(map[string]any)
	if !ok {
		t.Fatalf("AuberdineExporterDB absent ou de mauvais type: %T", got["AuberdineExporterDB"])
	}
	if db["version"] != "1.6.4" {
		t.Errorf("version = %v, attendu 1.6.4", db["version"])
	}

	chars := db["characters"].(map[string]any)
	carn := chars["Carnalis-Auberdine"].(map[string]any)
	if carn["name"] != "Carnalis" {
		t.Errorf("name = %v", carn["name"])
	}
	if carn["level"].(float64) != 60 {
		t.Errorf("level = %v", carn["level"])
	}
	if carn["enabled"] != true {
		t.Errorf("enabled = %v", carn["enabled"])
	}

	// skills doit être détecté comme tableau.
	skills, ok := carn["skills"].([]any)
	if !ok {
		t.Fatalf("skills n'est pas un tableau: %T", carn["skills"])
	}
	if !reflect.DeepEqual(skills, []any{"Cooking", "First Aid"}) {
		t.Errorf("skills = %v", skills)
	}

	// completedQuests : clés entières quotées → map.
	quests := carn["completedQuests"].(map[string]any)
	if quests["123"].(float64) != 1733500000 {
		t.Errorf("completedQuests[123] = %v", quests["123"])
	}
}

func TestParseStringEscapes(t *testing.T) {
	src := `X = { ["a"] = "ligne1\nligne2", ["b"] = "tab\tici", ["item"] = "|cffffffff[Épée]|r" }`
	got, err := Parse(src)
	if err != nil {
		t.Fatalf("Parse a échoué: %v", err)
	}
	x := got["X"].(map[string]any)
	if x["a"] != "ligne1\nligne2" {
		t.Errorf("a = %q", x["a"])
	}
	if x["b"] != "tab\tici" {
		t.Errorf("b = %q", x["b"])
	}
}

func TestParseArrayWithExplicitIndices(t *testing.T) {
	src := `T = { [1] = "x", [2] = "y", [3] = "z" }`
	got, err := Parse(src)
	if err != nil {
		t.Fatalf("Parse a échoué: %v", err)
	}
	arr, ok := got["T"].([]any)
	if !ok {
		t.Fatalf("T n'est pas un tableau: %T", got["T"])
	}
	if !reflect.DeepEqual(arr, []any{"x", "y", "z"}) {
		t.Errorf("T = %v", arr)
	}
}

func TestParseEmptyTable(t *testing.T) {
	got, err := Parse(`E = {}`)
	if err != nil {
		t.Fatalf("Parse a échoué: %v", err)
	}
	if m, ok := got["E"].(map[string]any); !ok || len(m) != 0 {
		t.Errorf("E = %v (%T)", got["E"], got["E"])
	}
}
