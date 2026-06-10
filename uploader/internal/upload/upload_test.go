package upload

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func keyFn(k string) func() string { return func() string { return k } }

func TestSendExportWrapsJSONData(t *testing.T) {
	var gotAuth, gotPath string
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotPath = r.URL.Path
		json.NewDecoder(r.Body).Decode(&body)
		w.WriteHeader(200)
		w.Write([]byte(`{"success":true,"processed":3}`))
	}))
	defer srv.Close()

	c := NewHTTP(srv.URL, keyFn("ak_secret"))
	res, err := c.SendExport(context.Background(), "SIGNED-PAYLOAD")
	if err != nil {
		t.Fatalf("SendExport: %v", err)
	}
	if gotAuth != "Bearer ak_secret" {
		t.Errorf("Authorization = %q", gotAuth)
	}
	if gotPath != "/ingest/export" {
		t.Errorf("path = %q", gotPath)
	}
	if body["jsonData"] != "SIGNED-PAYLOAD" {
		t.Errorf("jsonData = %v, attendu l'export brut enveloppé", body["jsonData"])
	}
	if res.Processed != 3 {
		t.Errorf("processed = %d", res.Processed)
	}
}

func TestSendDungeonLogBuildsMeta(t *testing.T) {
	raw := []byte("4/22 19:30:15.123  SPELL_DAMAGE,Player\n")
	var body struct {
		Meta struct {
			SHA256   string `json:"sha256"`
			SizeRaw  int    `json:"sizeRaw"`
			Client   string `json:"client"`
			Realm    string `json:"realm"`
			Uploader string `json:"uploader"`
			Instance struct {
				Name  string `json:"name"`
				MapID int64  `json:"mapId"`
			} `json:"instance"`
			LogFormat string `json:"logFormat"`
		} `json:"meta"`
		LogGzipBase64 string `json:"logGzipBase64"`
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewDecoder(r.Body).Decode(&body)
		w.WriteHeader(201)
		w.Write([]byte(`{"success":true,"uploadId":42,"duplicate":false,"status":"stored"}`))
	}))
	defer srv.Close()

	c := NewHTTP(srv.URL, keyFn("ak_x"))
	res, err := c.SendDungeonLog(context.Background(), CombatMeta{
		Realm: "auberdine", Uploader: "Carnalis", InstanceName: "Stratholme", MapID: 329,
		StartedAt: 1, EndedAt: 2,
	}, raw)
	if err != nil {
		t.Fatalf("SendDungeonLog: %v", err)
	}

	// sha256 + taille brute calculés côté client.
	wantSum := sha256.Sum256(raw)
	if body.Meta.SHA256 != hex.EncodeToString(wantSum[:]) {
		t.Errorf("sha256 = %q", body.Meta.SHA256)
	}
	if body.Meta.SizeRaw != len(raw) {
		t.Errorf("sizeRaw = %d, attendu %d", body.Meta.SizeRaw, len(raw))
	}
	if body.Meta.Instance.Name != "Stratholme" || body.Meta.Instance.MapID != 329 {
		t.Errorf("instance = %+v", body.Meta.Instance)
	}
	if body.Meta.Uploader != "Carnalis" || body.Meta.Realm != "auberdine" {
		t.Errorf("uploader/realm = %q/%q", body.Meta.Uploader, body.Meta.Realm)
	}
	if body.Meta.LogFormat == "" || body.Meta.Client != clientName {
		t.Errorf("meta client/logFormat = %q/%q", body.Meta.Client, body.Meta.LogFormat)
	}

	// Le base64 doit se dégzipper exactement vers le segment brut.
	gz, err := base64.StdEncoding.DecodeString(body.LogGzipBase64)
	if err != nil {
		t.Fatalf("base64: %v", err)
	}
	zr, err := gzip.NewReader(bytes.NewReader(gz))
	if err != nil {
		t.Fatalf("gzip: %v", err)
	}
	dec, _ := io.ReadAll(zr)
	if !bytes.Equal(dec, raw) {
		t.Errorf("contenu dégzippé = %q, attendu %q", dec, raw)
	}
	if res.UploadID != 42 || res.Duplicate {
		t.Errorf("résultat = %+v", res)
	}
}

func TestDuplicateIsSuccess(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.Write([]byte(`{"success":true,"uploadId":7,"duplicate":true,"status":"stored"}`))
	}))
	defer srv.Close()
	c := NewHTTP(srv.URL, keyFn("ak_x"))
	res, err := c.SendDungeonLog(context.Background(), CombatMeta{}, []byte("x"))
	if err != nil {
		t.Fatalf("attendu succès sur duplicate, obtenu %v", err)
	}
	if !res.Duplicate {
		t.Errorf("duplicate non remonté: %+v", res)
	}
}

func TestDefinitiveErrorNotRetried(t *testing.T) {
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(400)
		w.Write([]byte(`{"success":false,"error":"invalid_signature","message":"export altéré"}`))
	}))
	defer srv.Close()
	c := NewHTTP(srv.URL, keyFn("ak_x"))
	_, err := c.SendExport(context.Background(), "bad")
	if err == nil {
		t.Fatal("attendu une erreur")
	}
	if !IsDefinitive(err) {
		t.Errorf("4xx devrait être définitif: %v", err)
	}
	if calls != 1 {
		t.Errorf("un 4xx ne doit pas être retenté: %d appels", calls)
	}
}

func TestMissingAPIKeyFailsFast(t *testing.T) {
	c := NewHTTP("https://example.invalid", keyFn(""))
	if _, err := c.Status(context.Background()); err == nil {
		t.Fatal("attendu une erreur sans clé API")
	}
}

func TestAuthErrorNotDefinitive(t *testing.T) {
	// Un 401 (clé révoquée) N'EST PAS définitif : marquer le contenu
	// « transmis » sur une erreur d'auth le perdrait à jamais — la clé,
	// elle, se reconnecte. Cas réel : runs grillés du 2026-06-10.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
		w.Write([]byte(`{"success":false,"error":"invalid_api_key","message":"Clé API inconnue ou révoquée."}`))
	}))
	defer srv.Close()
	c := NewHTTP(srv.URL, keyFn("ak_morte"))
	_, err := c.SendExport(context.Background(), "payload")
	if err == nil {
		t.Fatal("attendu une erreur")
	}
	if IsDefinitive(err) {
		t.Errorf("401 ne doit PAS être définitif (transitoire, la clé se refait): %v", err)
	}
}
