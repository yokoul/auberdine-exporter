package app

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// fakeUploader capture les appels pour les assertions.
type fakeUploader struct {
	exports []string
	runs    []capturedRun
	err     error
}

type capturedRun struct {
	meta upload.CombatMeta
	raw  []byte
}

func (f *fakeUploader) Status(context.Context) (upload.StatusResponse, error) {
	return upload.StatusResponse{Success: true}, nil
}

func (f *fakeUploader) SendExport(_ context.Context, jsonData string) (upload.ExportResult, error) {
	if f.err != nil {
		return upload.ExportResult{}, f.err
	}
	f.exports = append(f.exports, jsonData)
	return upload.ExportResult{Processed: 1}, nil
}

func (f *fakeUploader) SendDungeonLog(_ context.Context, meta upload.CombatMeta, raw []byte) (upload.CombatResult, error) {
	if f.err != nil {
		return upload.CombatResult{}, f.err
	}
	cp := make([]byte, len(raw))
	copy(cp, raw)
	f.runs = append(f.runs, capturedRun{meta, cp})
	return upload.CombatResult{UploadID: 1, Status: "stored"}, nil
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
	// État isolé dans un répertoire temporaire (cross-platform : UserCacheDir
	// n'honore pas XDG_CACHE_HOME sur macOS/Windows).
	t.Setenv(StateDirEnv, t.TempDir())
	cfg := config.Default()
	cfg.WoWPath = root
	cfg.APIKey = "ak_test"
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
		["uploaderExport"] = {
			["schema"] = 1,
			["generatedAt"] = 1733500000,
			["payload"] = "SIGNED-EXPORT-A",
		},
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
	if up.exports[0] != "SIGNED-EXPORT-A" {
		t.Errorf("payload transmis = %q, attendu l'export signé brut", up.exports[0])
	}

	// Deuxième passage sans changement : dédup, aucun nouvel envoi.
	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatalf("2e export: %v", err)
	}
	if len(up.exports) != 1 {
		t.Fatalf("dédup ratée: %d envois", len(up.exports))
	}
}

func TestProcessExportSkipsWhenNoSignedExport(t *testing.T) {
	// SavedVariable présente mais sans uploaderExport (logout pas encore survenu).
	root := setupWoW(t, `AuberdineExporterDB = { ["accountKey"] = "a", ["characters"] = { ["X"] = { ["level"] = 1 } } }`)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)
	if err := a.processExport(context.Background(), a.Paths().SavedVars[0]); err != nil {
		t.Fatal(err)
	}
	if len(up.exports) != 0 {
		t.Fatalf("aucun export attendu sans uploaderExport, obtenu %d", len(up.exports))
	}
}

func TestProcessExportResendsOnChange(t *testing.T) {
	root := setupWoW(t, `AuberdineExporterDB = { ["uploaderExport"] = { ["payload"] = "SIGNED-A" } }`)
	up := &fakeUploader{}
	a := newTestApp(t, root, up)
	svPath := a.Paths().SavedVars[0]
	ctx := context.Background()

	if err := a.processExport(ctx, svPath); err != nil {
		t.Fatal(err)
	}
	// Modifie l'export signé.
	newSV := `AuberdineExporterDB = { ["uploaderExport"] = { ["payload"] = "SIGNED-B" } }`
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
					["instanceId"] = 36,
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
	m := up.runs[0].meta
	if m.InstanceName != "Deadmines" || m.MapID != 36 {
		t.Errorf("instance inattendue: %+v", m)
	}
	if m.Uploader != "Carnalis" || m.Realm != "auberdine" {
		t.Errorf("uploader/realm inattendus: %+v", m)
	}
	if string(up.runs[0].raw) != "HELLO WORLD" {
		t.Errorf("segment = %q, attendu les 11 premiers octets", up.runs[0].raw)
	}

	// Deuxième passage : run déjà transmis → dédup.
	if err := a.processDungeonLogs(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(up.runs) != 1 {
		t.Fatalf("dédup run ratée: %d envois", len(up.runs))
	}
}
