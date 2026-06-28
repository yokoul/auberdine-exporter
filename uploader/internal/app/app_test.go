package app

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
)

// fakeUploader capture les appels pour les assertions.
type fakeUploader struct {
	exports  []string
	runs     []capturedRun
	err      error
	messages []upload.InboxMessage
	acked    []string
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

func (f *fakeUploader) Messages(context.Context) ([]upload.InboxMessage, error) {
	return f.messages, nil
}

func (f *fakeUploader) AckMessages(_ context.Context, ids []string) error {
	f.acked = append(f.acked, ids...)
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

	// Écrit un log de combat factice (nom legacy, toujours détecté).
	logDir := a.Paths().LogsDir
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(logDir, "WoWCombatLog.txt"), []byte("HELLO WORLD extra"), 0o644); err != nil {
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

func TestGroupTwinRuns(t *testing.T) {
	now := int64(10_000)
	runs := []manifestRun{
		// Session 1 : deux jumeaux dual-box du même donjon, fenêtres décalées.
		{ID: "a", InstanceID: 189, StartedAt: 1000, EndedAt: 2000, Status: "complete"},
		{ID: "b", InstanceID: 189, StartedAt: 1004, EndedAt: 1990, Status: "complete"},
		// Session 2 : reset suivant (pas de chevauchement) → groupe distinct.
		{ID: "c", InstanceID: 189, StartedAt: 2500, EndedAt: 3200, Status: "complete"},
		// Autre instance au même moment → jamais regroupée.
		{ID: "d", InstanceID: 36, StartedAt: 1100, EndedAt: 1900, Status: "complete"},
	}
	groups := groupTwinRuns(runs, now)
	if len(groups) != 3 {
		t.Fatalf("3 groupes attendus, %d obtenus", len(groups))
	}
	byFirst := map[string]int{}
	for _, g := range groups {
		byFirst[g[0].ID] = len(g)
	}
	if byFirst["a"] != 2 {
		t.Errorf("jumeaux a+b non regroupés: %+v", byFirst)
	}
	if byFirst["c"] != 1 || byFirst["d"] != 1 {
		t.Errorf("reset/instance distincte regroupés à tort: %+v", byFirst)
	}

	// Un jumeau in_progress occupe sa fenêtre jusqu'à maintenant : il agrège
	// le run complet qui démarre après lui (la session n'est pas close).
	open := []manifestRun{
		{ID: "x", InstanceID: 189, StartedAt: 1000, EndedAt: 0, Status: "in_progress"},
		{ID: "y", InstanceID: 189, StartedAt: 5000, EndedAt: 6000, Status: "complete"},
	}
	g2 := groupTwinRuns(open, now)
	if len(g2) != 1 || len(g2[0]) != 2 {
		t.Fatalf("in_progress devrait agréger le run chevauchant: %+v", g2)
	}
}

func TestDropStaleRuns(t *testing.T) {
	now := int64(1_000_000)
	old := now - int64((twinStaleAfter + time.Hour) / time.Second)
	runs := []manifestRun{
		// Zombie : in_progress depuis > twinStaleAfter → écarté.
		{ID: "zombie", InstanceID: 389, StartedAt: old, Status: "in_progress"},
		// In_progress récent : conservé (il diffère légitimement son groupe).
		{ID: "live", InstanceID: 389, StartedAt: now - 600, Status: "in_progress"},
		// Complete ancien : conservé (l'âge ne concerne que les in_progress).
		{ID: "done", InstanceID: 389, StartedAt: old, EndedAt: old + 1200, Status: "complete"},
	}
	out := dropStaleRuns(runs, now)
	if len(out) != 2 {
		t.Fatalf("attendu 2 runs après filtre, obtenu %d", len(out))
	}
	for _, r := range out {
		if r.ID == "zombie" {
			t.Errorf("le zombie in_progress aurait dû être écarté")
		}
	}
}
