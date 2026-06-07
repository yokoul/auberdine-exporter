package selfupdate

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
	"github.com/yokoul/auberdine-exporter/uploader/internal/version"
)

func sum(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func TestAvailable(t *testing.T) {
	orig := version.Version
	defer func() { version.Version = orig }()

	asset := upload.ReleaseAsset{URL: "https://example.org/bin", SHA256: "abc"}
	rel := &upload.ClientRelease{
		Latest: "v0.2.0",
		Assets: map[string]upload.ReleaseAsset{AssetName(): asset},
	}

	version.Version = "v0.1.0"
	if _, ok := Available(rel); !ok {
		t.Fatal("v0.1.0 < v0.2.0 : mise à jour attendue")
	}
	version.Version = "v0.2.0"
	if _, ok := Available(rel); ok {
		t.Fatal("déjà à jour : pas de mise à jour attendue")
	}
	version.Version = "dev"
	if _, ok := Available(rel); ok {
		t.Fatal("build dev : jamais de mise à jour")
	}
	version.Version = "v0.1.0"
	if _, ok := Available(nil); ok {
		t.Fatal("release absente : pas de mise à jour")
	}
	// URL non-HTTPS refusée.
	insecure := &upload.ClientRelease{
		Latest: "v0.2.0",
		Assets: map[string]upload.ReleaseAsset{AssetName(): {URL: "http://example.org/bin", SHA256: "abc"}},
	}
	if _, ok := Available(insecure); ok {
		t.Fatal("URL http : doit être refusée")
	}
	// SHA absent refusé.
	nosha := &upload.ClientRelease{
		Latest: "v0.2.0",
		Assets: map[string]upload.ReleaseAsset{AssetName(): {URL: "https://example.org/bin"}},
	}
	if _, ok := Available(nosha); ok {
		t.Fatal("sha256 absent : doit être refusé")
	}
}

func TestApplyToSwapsBinary(t *testing.T) {
	newBin := []byte("#!/bin/sh\necho v2\n")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(newBin)
	}))
	defer srv.Close()

	dir := t.TempDir()
	exe := filepath.Join(dir, "uploader")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}

	asset := upload.ReleaseAsset{URL: srv.URL, SHA256: sum(newBin)}
	got, err := applyTo(context.Background(), asset, exe)
	if err != nil {
		t.Fatalf("applyTo: %v", err)
	}
	if got != exe {
		t.Fatalf("chemin renvoyé %q, attendu %q", got, exe)
	}
	data, err := os.ReadFile(exe)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != string(newBin) {
		t.Fatal("le binaire en place n'est pas le nouveau contenu")
	}
	if _, err := os.Stat(exe + ".new"); !os.IsNotExist(err) {
		t.Fatal(".new résiduel")
	}
}

func TestApplyToRejectsBadSHA(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("contenu inattendu"))
	}))
	defer srv.Close()

	dir := t.TempDir()
	exe := filepath.Join(dir, "uploader")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}

	asset := upload.ReleaseAsset{URL: srv.URL, SHA256: sum([]byte("autre chose"))}
	if _, err := applyTo(context.Background(), asset, exe); err == nil {
		t.Fatal("empreinte invalide : erreur attendue")
	}
	// Le binaire d'origine doit être intact.
	data, _ := os.ReadFile(exe)
	if string(data) != "old" {
		t.Fatal("le binaire d'origine a été altéré malgré l'empreinte invalide")
	}
	if _, err := os.Stat(exe + ".new"); !os.IsNotExist(err) {
		t.Fatal(".new résiduel après échec")
	}
}
