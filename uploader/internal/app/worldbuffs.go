package app

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/atomicfile"
	"github.com/yokoul/auberdine-exporter/uploader/internal/luasv"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

const worldbuffsVar = "AuberdineWorldbuffsFeed"

// worldbuffsRefreshMax : au-delà de cet âge du tampon fetchedAt présent dans
// le fichier, on réécrit même à contenu identique. C'est ce qui fait avancer
// l'horloge de fraîcheur lue en jeu : l'addon coupe l'affichage quand
// fetchedAt dépasse 12 h — sans réécriture périodique, un agenda stable
// paraîtrait périmé à tort.
const worldbuffsRefreshMax = time.Hour

// syncWorldbuffs réalise un cycle du flux descendant worldbuffs (site →
// uploader → addon) : récupère l'agenda des poses planifiées puis l'écrit
// dans le bloc AuberdineWorldbuffsFeed de chaque fichier SavedVariables —
// même écriture chirurgicale que syncMessages (remplace ce seul bloc
// top-level), même contrainte WoW (l'écriture « prend » quand le jeu est
// fermé ; sinon elle sera réappliquée au cycle suivant).
func (a *App) syncWorldbuffs(ctx context.Context) {
	if a.APIKey() == "" {
		return
	}
	feed, err := a.uploader.Worldbuffs(ctx)
	if err != nil {
		return // transitoire / endpoint absent (vieux serveur) : on retentera
	}

	now := time.Now().Unix()
	desired := worldbuffsKeySet(feed.Entries)
	block := encodeWorldbuffsBlock(feed, now)

	for _, p := range a.paths.SavedVars {
		raw, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		if parsed, err := luasv.Parse(string(raw)); err == nil {
			if cur, ok := parsed[worldbuffsVar].(map[string]any); ok {
				fetchedAt, _ := cur["fetchedAt"].(float64)
				fresh := now-int64(fetchedAt) < int64(worldbuffsRefreshMax/time.Second)
				if fresh && sameIDSet(parsedWorldbuffsKeySet(cur), desired) {
					continue // à jour et frais : aucune réécriture
				}
			}
		}
		updated, err := replaceTopLevelBlock(string(raw), worldbuffsVar, block)
		if err != nil {
			a.logger.Printf("worldbuffs %s : %v", p, err)
			continue
		}
		if err := atomicfile.Write(p, []byte(updated), 0o644); err != nil {
			a.logger.Printf("worldbuffs écriture %s : %v", p, err)
		}
	}
}

// worldbuffsKeySet projette les entrées du flux en ensemble de clés stables
// (comparaison de contenu entre le serveur et le fichier déjà écrit).
func worldbuffsKeySet(entries []upload.WorldbuffEntry) map[string]bool {
	set := map[string]bool{}
	for _, e := range entries {
		set[fmt.Sprintf("%s|%d|%s|%s", e.Buff, e.At, e.Guild, e.Faction)] = true
	}
	return set
}

// parsedWorldbuffsKeySet reconstruit le même ensemble de clés depuis le bloc
// Lua déjà présent dans le fichier SavedVariables.
func parsedWorldbuffsKeySet(cur map[string]any) map[string]bool {
	set := map[string]bool{}
	entries, ok := cur["entries"].([]any)
	if !ok {
		return set
	}
	for _, e := range entries {
		ee, ok := e.(map[string]any)
		if !ok {
			continue
		}
		buff, _ := ee["buff"].(string)
		at, _ := ee["at"].(float64)
		guild, _ := ee["guild"].(string)
		faction, _ := ee["faction"].(string)
		set[fmt.Sprintf("%s|%d|%s|%s", buff, int64(at), guild, faction)] = true
	}
	return set
}

// encodeWorldbuffsBlock sérialise la valeur Lua de AuberdineWorldbuffsFeed.
// entries est une SÉQUENCE (ipairs côté addon), déjà triée par le serveur en
// chronologique croissant.
func encodeWorldbuffsBlock(feed upload.WorldbuffsFeed, fetchedAt int64) string {
	var b strings.Builder
	b.WriteString("{\n\tschema = 1,\n")
	fmt.Fprintf(&b, "\tfetchedAt = %d,\n", fetchedAt)
	if feed.GeneratedAt > 0 {
		fmt.Fprintf(&b, "\tgeneratedAt = %d,\n", feed.GeneratedAt)
	}
	b.WriteString("\tentries = {\n")
	for _, e := range feed.Entries {
		b.WriteString("\t\t{\n")
		fmt.Fprintf(&b, "\t\t\tbuff = %s,\n", luaStr(e.Buff))
		fmt.Fprintf(&b, "\t\t\tat = %d,\n", e.At)
		if e.Guild != "" {
			fmt.Fprintf(&b, "\t\t\tguild = %s,\n", luaStr(e.Guild))
		}
		if e.Faction != "" {
			fmt.Fprintf(&b, "\t\t\tfaction = %s,\n", luaStr(e.Faction))
		}
		b.WriteString("\t\t},\n")
	}
	b.WriteString("\t},\n}")
	return b.String()
}
