package app

import (
	"bufio"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

// segMargin élargit légèrement la fenêtre temporelle pour ne pas tronquer les
// premières/dernières lignes d'un run (l'addon borne sur des events de zone,
// le log sur l'horodatage de chaque ligne).
const segMargin = 5 * time.Second

// segmentByTime extrait, du log de combat, le bloc brut des lignes dont
// l'horodatage tombe dans [startedAt, endedAt] (avec marge). Le contenu est
// renvoyé tel quel — l'uploader ne fait que découper, jamais interpréter.
//
// year sert à reconstruire un epoch : les lignes de log WoW portent un
// horodatage "M/J HH:MM:SS.mmm" sans année. Comme l'uploader tourne sur la
// même machine que le client, le fuseau local est cohérent avec le time() Lua.
func segmentByTime(path string, startedAt, endedAt int64, year int) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	lo := startedAt - int64(segMargin.Seconds())
	hi := endedAt + int64(segMargin.Seconds())

	var out []byte
	var started bool
	r := bufio.NewReader(f)
	for {
		line, err := r.ReadBytes('\n')
		if len(line) > 0 {
			ts, ok := parseCombatTimestamp(string(line), year)
			switch {
			case ok && ts >= lo && ts <= hi:
				out = append(out, line...)
				started = true
			case ok && ts > hi:
				// On a dépassé la fenêtre : inutile de lire la suite.
				return out, nil
			case !ok && started:
				// Ligne sans horodatage exploitable au milieu du run : on la
				// conserve pour ne pas casser le bloc brut.
				out = append(out, line...)
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return out, err
		}
	}
	return out, nil
}

// parseCombatTimestamp lit le préfixe horodaté d'une ligne de log de combat WoW
// et le convertit en epoch (secondes). Formats gérés : "M/J HH:MM:SS.mmm" et
// "M/J/AAAA HH:MM:SS.mmm". Le fuseau local est utilisé.
func parseCombatTimestamp(line string, year int) (int64, bool) {
	// Le séparateur entre l'horodatage et l'événement est un double espace.
	idx := strings.Index(line, "  ")
	if idx < 0 {
		return 0, false
	}
	prefix := strings.TrimSpace(line[:idx])
	parts := strings.Fields(prefix)
	if len(parts) < 2 {
		return 0, false
	}
	date, clock := parts[0], parts[1]

	dseg := strings.Split(date, "/")
	if len(dseg) < 2 {
		return 0, false
	}
	month, ok1 := atoi(dseg[0])
	day, ok2 := atoi(dseg[1])
	if !ok1 || !ok2 {
		return 0, false
	}
	y := year
	if len(dseg) >= 3 {
		if yy, ok := atoi(dseg[2]); ok {
			if yy < 100 {
				yy += 2000
			}
			y = yy
		}
	}

	tseg := strings.Split(clock, ":")
	if len(tseg) < 3 {
		return 0, false
	}
	hour, ok3 := atoi(tseg[0])
	min, ok4 := atoi(tseg[1])
	if !ok3 || !ok4 {
		return 0, false
	}
	// La partie secondes peut porter des millisecondes : "15.123".
	secStr := tseg[2]
	if dot := strings.IndexByte(secStr, '.'); dot >= 0 {
		secStr = secStr[:dot]
	}
	sec, ok5 := atoi(secStr)
	if !ok5 {
		return 0, false
	}

	t := time.Date(y, time.Month(month), day, hour, min, sec, 0, time.Local)
	return t.Unix(), true
}

func atoi(s string) (int, bool) {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	return n, err == nil
}
