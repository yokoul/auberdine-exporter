package app

import (
	"context"
	"testing"
)

// La SavedVariable porte un world boss (direct), un kill relayé, et une
// entrée invalide (sans personnage) qui doit être ignorée.
const meshSV = `
AuberdineExporterDB = {
	["worldbossSightings"] = {
		{ -- [1]
			["npcId"] = 6109,
			["name"] = "Azuregos",
			["at"] = 1752860000,
			["character"] = "Carna",
			["realm"] = "Auberdine",
			["guild"] = "Constellation",
			["faction"] = "ALLIANCE",
			["zone"] = "Azshara",
		}, -- [1]
		{ -- [2] entrée invalide (pas de personnage) : ignorée
			["npcId"] = 12397,
			["at"] = 1752860100,
			["realm"] = "Auberdine",
		}, -- [2]
	},
	["raidkillSightings"] = {
		{ -- [1]
			["encounterId"] = 663,
			["name"] = "Lucifron",
			["at"] = 1752861000,
			["character"] = "Carna",
			["realm"] = "Auberdine",
			["guild"] = "Constellation",
			["faction"] = "ALLIANCE",
			["instanceId"] = 409,
			["relayed"] = true,
		}, -- [1]
	},
}
`

func TestSyncMeshSightings(t *testing.T) {
	root := setupWoW(t, meshSV)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)
	ctx := context.Background()

	a.syncMeshSightings(ctx)

	wb := up.meshSightings["worldbosses"]
	if len(wb) != 1 {
		t.Fatalf("worldbosses : %d observation(s), attendu 1", len(wb))
	}
	if wb[0]["npcId"] != int64(6109) || wb[0]["zone"] != "Azshara" {
		t.Fatalf("worldboss inattendu : %#v", wb[0])
	}
	if _, ok := wb[0]["relayed"]; ok {
		t.Fatalf("observation directe marquée relayed : %#v", wb[0])
	}

	rk := up.meshSightings["raidkills"]
	if len(rk) != 1 {
		t.Fatalf("raidkills : %d observation(s), attendu 1", len(rk))
	}
	if rk[0]["encounterId"] != int64(663) || rk[0]["instanceId"] != int64(409) || rk[0]["relayed"] != true {
		t.Fatalf("raidkill inattendu : %#v", rk[0])
	}

	// Second passage : tout est déjà marqué transmis dans le state.
	a.syncMeshSightings(ctx)
	if len(up.meshSightings["worldbosses"]) != 1 || len(up.meshSightings["raidkills"]) != 1 {
		t.Fatalf("re-sync a renvoyé des observations déjà transmises")
	}
}
