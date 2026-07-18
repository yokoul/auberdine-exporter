package app

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

func TestSyncWorldbuffs_WritesThenSkipsWhenFresh(t *testing.T) {
	sv := `AuberdineExporterDB = {
	["version"] = "1.7.5",
	["characters"] = {
		["Carna-Auberdine"] = {
			["note"] = "garde { ces } accolades",
		},
	},
}
`
	root := setupWoW(t, sv)
	up := &fakeUploader{worldbuffs: upload.WorldbuffsFeed{
		GeneratedAt: 1752800000,
		Entries: []upload.WorldbuffEntry{
			{Buff: "Onyxia", At: 1752860000, Guild: `Les "Braves"`, Faction: "ALLIANCE"},
			{Buff: "Rend", At: 1752861800, Faction: "HORDE"},
		},
	}}
	a := newTestApp(t, root, up)
	svPath := a.Paths().SavedVars[0]
	ctx := context.Background()

	a.syncWorldbuffs(ctx)

	raw, err := os.ReadFile(svPath)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := luasv.Parse(string(raw))
	if err != nil {
		t.Fatalf("le résultat ne parse plus: %v", err)
	}
	// DB principale intacte.
	db, _ := parsed["AuberdineExporterDB"].(map[string]any)
	chars, _ := db["characters"].(map[string]any)
	carna, _ := chars["Carna-Auberdine"].(map[string]any)
	if carna == nil || carna["note"] != "garde { ces } accolades" {
		t.Fatalf("AuberdineExporterDB abîmé: %v", carna)
	}
	// Bloc worldbuffs écrit et complet.
	feed, _ := parsed[worldbuffsVar].(map[string]any)
	if feed == nil {
		t.Fatal("AuberdineWorldbuffsFeed absent")
	}
	entries, _ := feed["entries"].([]any)
	if len(entries) != 2 {
		t.Fatalf("attendu 2 entrées, obtenu %d", len(entries))
	}
	e0, _ := entries[0].(map[string]any)
	if e0["buff"] != "Onyxia" || e0["at"] != float64(1752860000) || e0["guild"] != `Les "Braves"` {
		t.Fatalf("entrée inattendue: %v", e0)
	}
	fetchedAt, _ := feed["fetchedAt"].(float64)
	if time.Since(time.Unix(int64(fetchedAt), 0)) > time.Minute {
		t.Fatalf("fetchedAt non posé à maintenant: %v", fetchedAt)
	}

	// Second cycle à contenu identique et tampon frais : aucune réécriture.
	before, _ := os.Stat(svPath)
	a.syncWorldbuffs(ctx)
	after, _ := os.Stat(svPath)
	if !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("réécriture inutile alors que le bloc est frais et identique")
	}

	// Contenu changé : la réécriture reprend.
	up.worldbuffs.Entries = up.worldbuffs.Entries[:1]
	a.syncWorldbuffs(ctx)
	raw, _ = os.ReadFile(svPath)
	parsed, err = luasv.Parse(string(raw))
	if err != nil {
		t.Fatalf("après mise à jour, le fichier ne parse plus: %v", err)
	}
	feed, _ = parsed[worldbuffsVar].(map[string]any)
	entries, _ = feed["entries"].([]any)
	if len(entries) != 1 {
		t.Fatalf("attendu 1 entrée après mise à jour, obtenu %d", len(entries))
	}
}

func TestSyncWorldbuffSightings_SendsOnceThenDedups(t *testing.T) {
	sv := `AuberdineExporterDB = {
	["version"] = "1.7.6",
	["wbSightings"] = {
		{ -- [1]
			["spellId"] = 22888,
			["name"] = "Cri de ralliement du tueur de dragons",
			["at"] = 1752860000,
			["character"] = "Carna",
			["realm"] = "Auberdine",
			["guild"] = "Constellation",
			["faction"] = "ALLIANCE",
			["zone"] = "Orgrimmar",
		}, -- [1]
		{ -- [2]
			["spellId"] = 16609,
			["at"] = 1752861800,
			["character"] = "Carna",
			["realm"] = "Auberdine",
		}, -- [2]
		{ -- [3] entrée invalide (pas de personnage) : ignorée
			["spellId"] = 24425,
			["at"] = 1752861900,
			["realm"] = "Auberdine",
		}, -- [3]
	},
}
`
	root := setupWoW(t, sv)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)
	ctx := context.Background()

	a.syncWorldbuffSightings(ctx)
	if len(up.sightings) != 2 {
		t.Fatalf("attendu 2 poses transmises, obtenu %d", len(up.sightings))
	}
	s0 := up.sightings[0]
	if s0.SpellID != 22888 || s0.Character != "Carna" || s0.Guild != "Constellation" || s0.At != 1752860000 {
		t.Fatalf("pose inattendue: %+v", s0)
	}

	// Second cycle : tout est déjà marqué transmis, aucun renvoi.
	a.syncWorldbuffSightings(ctx)
	if len(up.sightings) != 2 {
		t.Fatalf("renvoi indu : %d poses transmises au total", len(up.sightings))
	}
}
