package app

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// logLine formate une ligne de log de combat comme le client WoW.
func logLine(t time.Time, event string) string {
	return fmt.Sprintf("%d/%d %02d:%02d:%02d.%03d  %s\n",
		int(t.Month()), t.Day(), t.Hour(), t.Minute(), t.Second(),
		t.Nanosecond()/1e6, event)
}

func TestParseCombatTimestamp(t *testing.T) {
	ref := time.Date(2026, 4, 22, 19, 30, 15, 0, time.Local)
	line := logLine(ref, "SPELL_DAMAGE,Player-1,\"X\"")
	got, ok := parseCombatTimestamp(line, 2026)
	if !ok {
		t.Fatalf("timestamp non parsé: %q", line)
	}
	if got != ref.Unix() {
		t.Errorf("epoch = %d, attendu %d", got, ref.Unix())
	}

	if _, ok := parseCombatTimestamp("pas une ligne de log", 2026); ok {
		t.Errorf("ligne invalide acceptée à tort")
	}
}

func TestSegmentByTime(t *testing.T) {
	base := time.Date(2026, 4, 22, 19, 0, 0, 0, time.Local)
	var b strings.Builder
	// 0..9 minutes ; on cible la fenêtre [minute 3, minute 6].
	for i := 0; i < 10; i++ {
		b.WriteString(logLine(base.Add(time.Duration(i)*time.Minute), fmt.Sprintf("EVENT_%d", i)))
	}
	dir := t.TempDir()
	logPath := filepath.Join(dir, "WoWCombatLog.txt")
	if err := os.WriteFile(logPath, []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}

	start := base.Add(3 * time.Minute).Unix()
	end := base.Add(6 * time.Minute).Unix()
	seg, err := segmentByTime(logPath, start, end, 2026)
	if err != nil {
		t.Fatalf("segmentByTime: %v", err)
	}
	got := string(seg)

	// La marge (5 s) ne déborde pas jusqu'aux minutes voisines (60 s d'écart).
	for _, want := range []string{"EVENT_3", "EVENT_4", "EVENT_5", "EVENT_6"} {
		if !strings.Contains(got, want) {
			t.Errorf("segment ne contient pas %s:\n%s", want, got)
		}
	}
	for _, no := range []string{"EVENT_2", "EVENT_7", "EVENT_0", "EVENT_9"} {
		if strings.Contains(got, no) {
			t.Errorf("segment contient %s à tort:\n%s", no, got)
		}
	}
}

func TestSegmentByTimeEmptyWindow(t *testing.T) {
	base := time.Date(2026, 4, 22, 19, 0, 0, 0, time.Local)
	dir := t.TempDir()
	logPath := filepath.Join(dir, "WoWCombatLog.txt")
	if err := os.WriteFile(logPath, []byte(logLine(base, "EVENT_X")), 0o644); err != nil {
		t.Fatal(err)
	}
	// Fenêtre une heure plus tard : rien.
	seg, err := segmentByTime(logPath, base.Add(time.Hour).Unix(), base.Add(2*time.Hour).Unix(), 2026)
	if err != nil {
		t.Fatal(err)
	}
	if len(seg) != 0 {
		t.Errorf("attendu segment vide, obtenu %q", seg)
	}
}
