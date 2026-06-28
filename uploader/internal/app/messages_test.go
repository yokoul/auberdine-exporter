package app

import (
	"strings"
	"testing"

	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

func i64(v int64) *int64 { return &v }

// Un SavedVariables réaliste : AuberdineExporterDB d'abord, puis un bloc inbox
// déjà présent (format WoW avec commentaires « -- [N] » et accolades dans une
// chaîne) qu'il faut remplacer SANS abîmer le reste.
const sampleSV = `
AuberdineExporterDB = {
	["version"] = "1.7.4",
	["seenMessages"] = {
		["7"] = 1719500000,
	},
	["characters"] = {
		["Carna-Auberdine"] = {
			["note"] = "garde { ces } accolades",
		},
	},
}
AuberdineUploaderInbox = {
	["schema"] = 1,
	["messages"] = {
		{ -- [1]
			["id"] = "7",
			["body"] = "ancien message",
		}, -- [1]
	},
}
`

func TestReplaceTopLevelBlock_ReplacesInboxKeepsDB(t *testing.T) {
	block := encodeInboxBlock([]upload.InboxMessage{
		{ID: "9", Kind: "warning", Title: "Titre", Body: `corps avec "guillemets" et } accolade`, CreatedAt: i64(1719600000)},
	})
	out, err := replaceTopLevelBlock(sampleSV, inboxVar, block)
	if err != nil {
		t.Fatalf("replace: %v", err)
	}

	// Le résultat doit rester un SavedVariables valide.
	parsed, err := luasv.Parse(out)
	if err != nil {
		t.Fatalf("le résultat ne parse plus: %v", err)
	}

	// AuberdineExporterDB intact (seenMessages + note avec accolades).
	db, ok := parsed["AuberdineExporterDB"].(map[string]any)
	if !ok {
		t.Fatal("AuberdineExporterDB perdu")
	}
	sm, _ := db["seenMessages"].(map[string]any)
	if sm["7"] == nil {
		t.Fatal("seenMessages abîmé")
	}
	chars, _ := db["characters"].(map[string]any)
	carna, _ := chars["Carna-Auberdine"].(map[string]any)
	if carna == nil || carna["note"] != "garde { ces } accolades" {
		t.Fatalf("note de personnage abîmée: %v", carna)
	}

	// La nouvelle boîte contient le message 9 et plus le 7.
	inbox, ok := parsed[inboxVar].(map[string]any)
	if !ok {
		t.Fatal("AuberdineUploaderInbox absent après remplacement")
	}
	msgs, _ := inbox["messages"].([]any)
	if len(msgs) != 1 {
		t.Fatalf("attendu 1 message, obtenu %d", len(msgs))
	}
	m0, _ := msgs[0].(map[string]any)
	if m0["id"] != "9" || m0["kind"] != "warning" {
		t.Fatalf("message inattendu: %v", m0)
	}
	if m0["body"] != `corps avec "guillemets" et } accolade` {
		t.Fatalf("corps mal encodé/décodé: %q", m0["body"])
	}

	// Un seul bloc inbox dans le fichier (pas de duplication).
	if n := strings.Count(out, inboxVar+" = "); n != 1 {
		t.Fatalf("attendu 1 assignation inbox, obtenu %d", n)
	}
}

func TestReplaceTopLevelBlock_AppendsWhenAbsent(t *testing.T) {
	src := "AuberdineExporterDB = {\n\t[\"version\"] = \"1.7.4\",\n}\n"
	block := encodeInboxBlock([]upload.InboxMessage{{ID: "1", Body: "salut", CreatedAt: i64(1)}})
	out, err := replaceTopLevelBlock(src, inboxVar, block)
	if err != nil {
		t.Fatalf("append: %v", err)
	}
	parsed, err := luasv.Parse(out)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if _, ok := parsed[inboxVar].(map[string]any); !ok {
		t.Fatal("inbox non ajoutée")
	}
	if _, ok := parsed["AuberdineExporterDB"].(map[string]any); !ok {
		t.Fatal("DB perdue à l'ajout")
	}
}

func TestEncodeInboxBlock_Empty(t *testing.T) {
	out, err := replaceTopLevelBlock(sampleSV, inboxVar, encodeInboxBlock(nil))
	if err != nil {
		t.Fatalf("replace vide: %v", err)
	}
	parsed, err := luasv.Parse(out)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	inbox, _ := parsed[inboxVar].(map[string]any)
	if inbox == nil {
		t.Fatal("inbox absente")
	}
	if msgs, ok := inbox["messages"].([]any); ok && len(msgs) != 0 {
		t.Fatalf("messages devrait être vide, obtenu %d", len(msgs))
	}
}
