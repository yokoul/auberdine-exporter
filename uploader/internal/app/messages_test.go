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

// Une SavedVariable dont la valeur n'est pas une table (WoW écrit `= nil` ou un
// scalaire quand la table a été vidée) ne doit ni bloquer la réécriture, ni
// happer le bloc de la variable suivante. Cas observé en production : le feed
// worldbuffs échouait toutes les 2 min sur un compte (« pas de '{' »), et dans
// la variante où une autre variable suivait, celle-ci disparaissait purement.
func TestReplaceTopLevelBlock_ValeurScalaire(t *testing.T) {
	cases := []struct {
		name string
		src  string
	}{
		{"nil en fin de fichier", "AuberdineExporterDB = {\n\t[\"p\"] = 1,\n}\nAuberdineWorldbuffsFeed = nil\n"},
		{"scalaire en fin de fichier", "AuberdineExporterDB = {\n\t[\"p\"] = 1,\n}\nAuberdineWorldbuffsFeed = 1784595670\n"},
		{"nil suivi d'un autre bloc", "AuberdineWorldbuffsFeed = nil\nAuberdineExporterDB = {\n\t[\"p\"] = 1,\n}\n"},
		{"tronqué après le =", "AuberdineExporterDB = {\n\t[\"p\"] = 1,\n}\nAuberdineWorldbuffsFeed = "},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			out, err := replaceTopLevelBlock(c.src, "AuberdineWorldbuffsFeed", "{\n\tschema = 1,\n}")
			if err != nil {
				t.Fatalf("réécriture refusée : %v", err)
			}
			parsed, err := luasv.Parse(out)
			if err != nil {
				t.Fatalf("résultat illisible : %v\n%s", err, out)
			}
			feed, ok := parsed["AuberdineWorldbuffsFeed"].(map[string]any)
			if !ok {
				t.Fatalf("feed non réécrit en table :\n%s", out)
			}
			if feed["schema"] == nil {
				t.Fatalf("feed sans schema :\n%s", out)
			}
			// L'invariant : le bloc voisin survit intact.
			if strings.Contains(c.src, "AuberdineExporterDB") {
				db, ok := parsed["AuberdineExporterDB"].(map[string]any)
				if !ok {
					t.Fatalf("AuberdineExporterDB détruit par la réécriture :\n%s", out)
				}
				if db["p"] == nil {
					t.Fatalf("contenu de AuberdineExporterDB perdu :\n%s", out)
				}
			}
		})
	}
}
