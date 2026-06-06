package app

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// fakeUploader capture les appels pour les assertions.
type fakeUploader struct {
	exports []capturedExport
	runs    []upload.DungeonMeta
	err     error
}

type capturedExport struct {
	accountKey string
	payload    []byte
}

func (f *fakeUploader) SendExport(_ context.Context, accountKey string, payload []byte) error {
	if f.err != nil {
		return f.err
	}
	cp := make([]byte, len(payload))
	copy(cp, payload)
	f.exports = append(f.exports, capturedExport{accountKey, cp})
	return nil
}

func (f *fakeUploader) SendDungeonLog(_ context.Context, meta upload.DungeonMeta, _ []byte) error {
	if f.err != nil {
		return f.err
	}
	f.runs = append(f.runs, meta)
	return nil
}

// setupWoW crée une arborescence WoW minimale avec une SavedVariable.
func setupWoW(t *testing.T, sv string) string {
	t.Helper()
	root := t.TempDir()
	dir := filepath.Join(root, "WTF", "Account", "TESTACC", "SavedVariables")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "AuberdineExporter.lua"), []byte(sv), 0o644); err != nil {
		t.Fatal(err)
	}
	return root
}

func newTestApp(t *testing.T, root string, up *fakeUploader) *App {
	t.Helper()
	// État isolé dans un cache temporaire.
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	cfg := config.Default()
	cfg.WoWPath = root
	a, err := New(cfg, up, nil)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return a
}

func TestProcessExportSendsOnceThenDedups(t *testing.T) {
	sv := `AuberdineExporterDB = {
		["version"] = "1.6.4",
		["accountKey"] = "acc-xyz",
		["characters"] = { ["Carnalis-Auberdine"] = { ["name"] = "Carnalis", ["level"] = 60 } },
	}`
	root := setupWoW(t, sv)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)

	svPath := a.Paths().SavedVars[0]
	ctx := context.Background()

	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatalf("1er export: %v", err)
	}
	if len(up.exports) != 1 {
		t.Fatalf("attendu 1 export, obtenu %d", len(up.exports))
	}
	if up.exports[0].accountKey != "acc-xyz" {
		t.Errorf("accountKey = %q", up.exports[0].accountKey)
	}
	// Le payload doit être du JSON valide contenant les personnages.
	var decoded map[string]any
	if err := json.Unmarshal(up.exports[0].payload, &decoded); err != nil {
		t.Fatalf("payload non JSON: %v", err)
	}
	if _, ok := decoded["characters"]; !ok {
		t.Errorf("payload sans characters: %v", decoded)
	}

	// Deuxième passage sans changement : dédup, aucun nouvel envoi.
	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatalf("2e export: %v", err)
	}
	if len(up.exports) != 1 {
		t.Fatalf("dédup ratée: %d envois", len(up.exports))
	}
}

func TestProcessExportResendsOnChange(t *testing.T) {
	root := setupWoW(t, `AuberdineExporterDB = { ["accountKey"] = "a", ["characters"] = { ["X"] = { ["level"] = 1 } } }`)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)
	svPath := a.Paths().SavedVars[0]
	ctx := context.Background()

	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatal(err)
	}
	// Modifie le contenu.
	newSV := `AuberdineExporterDB = { ["accountKey"] = "a", ["characters"] = { ["X"] = { ["level"] = 2 } } }`
	if err := os.WriteFile(svPath, []byte(newSV), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatal(err)
	}
	if len(up.exports) != 2 {
		t.Fatalf("attendu 2 envois après changement, obtenu %d", len(up.exports))
	}
}

func TestDungeonManifestDrivesUpload(t *testing.T) {
	// SavedVariable avec un manifeste de run complet + un log de combat.
	root := setupWoW(t, `AuberdineExporterDB = {
		["accountKey"] = "a",
		["uploaderManifest"] = {
			["schema"] = 1,
			["runs"] = {
				{
					["id"] = "run-1",
					["instance"] = "Deadmines",
					["character"] = "Carnalis-Auberdine",
					["startedAt"] = 1733500000,
					["endedAt"] = 1733503600,
					["byteStart"] = 0,
					["byteEnd"] = 11,
					["status"] = "complete",
				},
			},
		},
	}`)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)

	// Écrit un log de combat factice à l'emplacement attendu.
	logDir := filepath.Dir(a.Paths().CombatLog)
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.Paths().CombatLog, []byte("HELLO WORLD extra"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := a.processDungeonLogs(context.Background()); err != nil {
		t.Fatalf("processDungeonLogs: %v", err)
	}
	if len(up.runs) != 1 {
		t.Fatalf("attendu 1 run transmis, obtenu %d", len(up.runs))
	}
	if up.runs[0].RunID != "run-1" || up.runs[0].Instance != "Deadmines" {
		t.Errorf("meta inattendue: %+v", up.runs[0])
	}

	// Deuxième passage : run déjà transmis → dédup.
	if err := a.processDungeonLogs(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(up.runs) != 1 {
		t.Fatalf("dédup run ratée: %d envois", len(up.runs))
	}
}
