package app

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/yokoul/auberdine-exporter/uploader/internal/atomicfile"
	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

const inboxVar = "AuberdineUploaderInbox"

// syncMessages réalise un cycle du canal descendant (site → uploader → addon) :
//   1. récupère les messages en attente (/ingest/messages) ;
//   2. lit, dans chaque fichier SavedVariables, les ids déjà vus en jeu
//      (AuberdineExporterDB.seenMessages) et les acquitte au serveur ;
//   3. écrit la boîte de réception voulue (messages pending non encore vus)
//      dans le bloc AuberdineUploaderInbox de chaque fichier — écriture
//      CHIRURGICALE qui remplace ce seul bloc top-level sans toucher au reste
//      (AuberdineExporterDB), et seulement si l'ensemble d'ids change.
//
// Contrainte WoW : un addon ne lit ses SavedVariables qu'au chargement et WoW
// réécrit le fichier au logout. L'écriture « prend » quand le jeu est fermé ;
// si WoW tourne, elle sera simplement réappliquée au cycle suivant. Atomique :
// jamais de fichier tronqué (cf. l'incident state.json).
func (a *App) syncMessages(ctx context.Context) {
	if a.APIKey() == "" {
		return
	}
	pending, err := a.uploader.Messages(ctx)
	if err != nil {
		return // transitoire / endpoint absent (vieux serveur) : on retentera
	}

	type svInfo struct {
		path     string
		raw      string
		inboxIDs map[string]bool
	}
	var files []svInfo
	seen := map[string]bool{}

	for _, p := range a.paths.SavedVars {
		raw, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		parsed, err := luasv.Parse(string(raw))
		if err != nil {
			continue
		}
		if db, ok := parsed["AuberdineExporterDB"].(map[string]any); ok {
			if sm, ok := db["seenMessages"].(map[string]any); ok {
				for id := range sm {
					seen[id] = true
				}
			}
		}
		ids := map[string]bool{}
		if inbox, ok := parsed[inboxVar].(map[string]any); ok {
			if msgs, ok := inbox["messages"].([]any); ok {
				for _, m := range msgs {
					if mm, ok := m.(map[string]any); ok {
						if id, ok := mm["id"].(string); ok {
							ids[id] = true
						}
					}
				}
			}
		}
		files = append(files, svInfo{path: p, raw: string(raw), inboxIDs: ids})
	}

	// Acquitte les messages encore « pending » côté serveur mais déjà vus en jeu.
	var toAck []string
	for _, m := range pending {
		if seen[m.ID] {
			toAck = append(toAck, m.ID)
		}
	}
	if err := a.uploader.AckMessages(ctx, toAck); err != nil {
		a.logger.Printf("ack messages : %v", err)
	}

	// Boîte voulue = pending pas encore vus.
	var desired []upload.InboxMessage
	desiredIDs := map[string]bool{}
	for _, m := range pending {
		if !seen[m.ID] {
			desired = append(desired, m)
			desiredIDs[m.ID] = true
		}
	}
	block := encodeInboxBlock(desired)

	for _, f := range files {
		if sameIDSet(f.inboxIDs, desiredIDs) {
			continue // déjà à jour : aucune réécriture
		}
		updated, err := replaceTopLevelBlock(f.raw, inboxVar, block)
		if err != nil {
			a.logger.Printf("messages %s : %v", f.path, err)
			continue
		}
		if err := atomicfile.Write(f.path, []byte(updated), 0o644); err != nil {
			a.logger.Printf("messages écriture %s : %v", f.path, err)
		}
	}
}

func sameIDSet(a, b map[string]bool) bool {
	if len(a) != len(b) {
		return false
	}
	for k := range a {
		if !b[k] {
			return false
		}
	}
	return true
}

// encodeInboxBlock sérialise la valeur Lua de AuberdineUploaderInbox (table
// { schema, messages = { … } }). messages est une SÉQUENCE (ipairs côté addon).
func encodeInboxBlock(msgs []upload.InboxMessage) string {
	var b strings.Builder
	b.WriteString("{\n\tschema = 1,\n\tmessages = {\n")
	for _, m := range msgs {
		kind := m.Kind
		if kind == "" {
			kind = "info"
		}
		b.WriteString("\t\t{\n")
		fmt.Fprintf(&b, "\t\t\tid = %s,\n", luaStr(m.ID))
		fmt.Fprintf(&b, "\t\t\tkind = %s,\n", luaStr(kind))
		if m.Title != "" {
			fmt.Fprintf(&b, "\t\t\ttitle = %s,\n", luaStr(m.Title))
		}
		fmt.Fprintf(&b, "\t\t\tbody = %s,\n", luaStr(m.Body))
		if m.CreatedAt != nil {
			fmt.Fprintf(&b, "\t\t\tcreatedAt = %d,\n", *m.CreatedAt)
		}
		if m.ExpiresAt != nil {
			fmt.Fprintf(&b, "\t\t\texpiresAt = %d,\n", *m.ExpiresAt)
		}
		b.WriteString("\t\t},\n")
	}
	b.WriteString("\t},\n}")
	return b.String()
}

// luaStr encode une chaîne en littéral Lua double-quoté (échappe \, ", et les
// caractères de contrôle).
func luaStr(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range s {
		switch r {
		case '\\':
			b.WriteString(`\\`)
		case '"':
			b.WriteString(`\"`)
		case '\n':
			b.WriteString(`\n`)
		case '\r':
			b.WriteString(`\r`)
		case '\t':
			b.WriteString(`\t`)
		default:
			if r < 0x20 {
				fmt.Fprintf(&b, `\%d`, r)
			} else {
				b.WriteRune(r)
			}
		}
	}
	b.WriteByte('"')
	return b.String()
}

// replaceTopLevelBlock remplace l'assignation top-level `varName = {…}` par
// `varName = value` dans src (WoW écrit chaque SavedVariable comme une
// assignation à la colonne 0). Si absente, l'assignation est ajoutée en fin de
// fichier. Ne touche à aucun autre bloc (notamment AuberdineExporterDB).
func replaceTopLevelBlock(src, varName, value string) (string, error) {
	assignment := varName + " = " + value
	idx := topLevelVarIndex(src, varName)
	if idx < 0 {
		sep := ""
		if len(src) > 0 && !strings.HasSuffix(src, "\n") {
			sep = "\n"
		}
		return src + sep + assignment + "\n", nil
	}
	eq := strings.IndexByte(src[idx:], '=')
	if eq < 0 {
		return "", fmt.Errorf("bloc %s : pas de '='", varName)
	}
	open := strings.IndexByte(src[idx+eq:], '{')
	if open < 0 {
		return "", fmt.Errorf("bloc %s : pas de '{'", varName)
	}
	openPos := idx + eq + open
	closePos, err := matchBrace(src, openPos)
	if err != nil {
		return "", fmt.Errorf("bloc %s : %w", varName, err)
	}
	return src[:idx] + assignment + src[closePos+1:], nil
}

// topLevelVarIndex renvoie l'index de début de l'assignation top-level de
// varName (début de fichier ou de ligne, suivi d'espaces puis '='), ou -1.
func topLevelVarIndex(src, varName string) int {
	if strings.HasPrefix(src, varName) && isAssign(src[len(varName):]) {
		return 0
	}
	needle := "\n" + varName
	from := 0
	for {
		i := strings.Index(src[from:], needle)
		if i < 0 {
			return -1
		}
		pos := from + i + 1 // saute le \n → début de varName
		if isAssign(src[pos+len(varName):]) {
			return pos
		}
		from = pos + len(varName)
	}
}

func isAssign(s string) bool {
	i := 0
	for i < len(s) && (s[i] == ' ' || s[i] == '\t') {
		i++
	}
	return i < len(s) && s[i] == '='
}

// matchBrace, partant du '{' à l'index open, renvoie l'index du '}' équilibré.
// Ignore les accolades à l'intérieur des chaînes double-quotées et des
// commentaires de ligne `--` (WoW émet « -- [N] » après les entrées de
// séquence).
func matchBrace(src string, open int) (int, error) {
	depth := 0
	inStr := false
	for i := open; i < len(src); i++ {
		c := src[i]
		if inStr {
			if c == '\\' {
				i++ // saute le caractère échappé
				continue
			}
			if c == '"' {
				inStr = false
			}
			continue
		}
		switch c {
		case '"':
			inStr = true
		case '-':
			if i+1 < len(src) && src[i+1] == '-' {
				j := strings.IndexByte(src[i:], '\n')
				if j < 0 {
					return -1, fmt.Errorf("commentaire non terminé")
				}
				i += j // se positionne sur le \n (la boucle l'incrémentera)
			}
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return i, nil
			}
		}
	}
	return -1, fmt.Errorf("accolade non équilibrée")
}
