package selfupdate

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
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

// testKeys installe une paire de clés de test à la place de la clé publique
// de release embarquée, et renvoie de quoi signer les binaires de test.
func testKeys(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	orig := releasePubKeyB64
	releasePubKeyB64 = base64.StdEncoding.EncodeToString(pub)
	t.Cleanup(func() { releasePubKeyB64 = orig })
	return priv
}

func signOf(priv ed25519.PrivateKey, data []byte) string {
	return base64.StdEncoding.EncodeToString(ed25519.Sign(priv, data))
}

func TestAvailable(t *testing.T) {
	orig := version.Version
	defer func() { version.Version = orig }()

	asset := upload.ReleaseAsset{URL: "https://example.org/bin", SHA256: "abc", Sig: "c2ln"}
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
		Assets: map[string]upload.ReleaseAsset{AssetName(): {URL: "http://example.org/bin", SHA256: "abc", Sig: "c2ln"}},
	}
	if _, ok := Available(insecure); ok {
		t.Fatal("URL http : doit être refusée")
	}
	// SHA absent refusé.
	nosha := &upload.ClientRelease{
		Latest: "v0.2.0",
		Assets: map[string]upload.ReleaseAsset{AssetName(): {URL: "https://example.org/bin", Sig: "c2ln"}},
	}
	if _, ok := Available(nosha); ok {
		t.Fatal("sha256 absent : doit être refusé")
	}
	// Signature absente refusée (audit 2026-06 : la mise à jour est signée).
	nosig := &upload.ClientRelease{
		Latest: "v0.2.0",
		Assets: map[string]upload.ReleaseAsset{AssetName(): {URL: "https://example.org/bin", SHA256: "abc"}},
	}
	if _, ok := Available(nosig); ok {
		t.Fatal("signature absente : doit être refusée")
	}
}

func TestApplyToSwapsBinary(t *testing.T) {
	priv := testKeys(t)
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

	asset := upload.ReleaseAsset{URL: srv.URL, SHA256: sum(newBin), Sig: signOf(priv, newBin)}
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
	priv := testKeys(t)
	payload := []byte("contenu inattendu")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(payload)
	}))
	defer srv.Close()

	dir := t.TempDir()
	exe := filepath.Join(dir, "uploader")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}

	asset := upload.ReleaseAsset{URL: srv.URL, SHA256: sum([]byte("autre chose")), Sig: signOf(priv, payload)}
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

// TestApplyToRejectsBadSignature : sha256 correct mais signature d'une autre
// clé (ou d'un autre contenu) — le swap doit être refusé, binaire intact.
// C'est LE scénario « serveur compromis » que la signature referme.
func TestApplyToRejectsBadSignature(t *testing.T) {
	testKeys(t)                                 // installe la clé publique de test…
	_, autrePriv, _ := ed25519.GenerateKey(nil) // …mais on signe avec une AUTRE clé
	newBin := []byte("#!/bin/sh\necho pwned\n")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(newBin)
	}))
	defer srv.Close()

	dir := t.TempDir()
	exe := filepath.Join(dir, "uploader")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}

	asset := upload.ReleaseAsset{URL: srv.URL, SHA256: sum(newBin), Sig: signOf(autrePriv, newBin)}
	if _, err := applyTo(context.Background(), asset, exe); err == nil {
		t.Fatal("signature d'une autre clé : erreur attendue")
	}
	data, _ := os.ReadFile(exe)
	if string(data) != "old" {
		t.Fatal("le binaire d'origine a été altéré malgré la signature invalide")
	}

	// Signature illisible (pas du base64 d'une taille de signature).
	asset.Sig = "pas-une-signature"
	if _, err := applyTo(context.Background(), asset, exe); err == nil {
		t.Fatal("signature illisible : erreur attendue")
	}
}

func TestDownloadURLAllowed(t *testing.T) {
	cases := map[string]bool{
		"https://github.com/x/y/releases/download/v1/bin": true,
		"http://127.0.0.1:8080/bin":                       true, // loopback (tests)
		"http://localhost:8080/bin":                       true,
		"http://example.org/bin":                          false,
		"ftp://example.org/bin":                           false,
		"://invalide":                                     false,
	}
	for raw, want := range cases {
		if got := downloadURLAllowed(raw); got != want {
			t.Errorf("downloadURLAllowed(%q) = %v, attendu %v", raw, got, want)
		}
	}
}
