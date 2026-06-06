package discovery

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Le client 1.15.8+ crée un log horodaté par session de logging — vérifie le
// parse du nom, l'inclusion du legacy et l'ordre (récent → ancien, legacy en
// dernier).
func TestListCombatLogs(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{
		"WoWCombatLog-060626_221910.txt", // 6 juin 2026 22:19:10
		"WoWCombatLog-060526_180000.txt", // 5 juin 2026 18:00:00
		"WoWCombatLog.txt",               // legacy sans horodatage
		"WoWCombatLog-bad.txt",           // nom non conforme : ignoré
		"Client.log",                     // autre log : ignoré
	} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	logs := ListCombatLogs(dir)
	if len(logs) != 3 {
		t.Fatalf("attendu 3 logs, obtenu %d", len(logs))
	}
	if filepath.Base(logs[0].Path) != "WoWCombatLog-060626_221910.txt" {
		t.Errorf("le plus récent d'abord, obtenu %s", logs[0].Path)
	}
	want := time.Date(2026, 6, 6, 22, 19, 10, 0, time.Local)
	if !logs[0].SessionStart.Equal(want) {
		t.Errorf("SessionStart: attendu %v, obtenu %v", want, logs[0].SessionStart)
	}
	if filepath.Base(logs[2].Path) != "WoWCombatLog.txt" || !logs[2].SessionStart.IsZero() {
		t.Errorf("legacy en dernier avec SessionStart zéro, obtenu %s (%v)",
			logs[2].Path, logs[2].SessionStart)
	}
}
