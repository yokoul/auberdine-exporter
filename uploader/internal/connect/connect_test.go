package connect

import (
	"context"
	"net/http"
	"net/url"
	"testing"
	"time"
)

// simulateServer rejoue ce que fera auberdine.eu : il reçoit l'URL de connexion,
// en extrait port + state, et appelle le callback loopback comme le ferait la
// redirection 302 (avec les paramètres fournis).
func simulateServer(t *testing.T, params url.Values) func(string) {
	t.Helper()
	return func(connectURL string) {
		u, err := url.Parse(connectURL)
		if err != nil {
			t.Errorf("URL de connexion invalide: %v", err)
			return
		}
		q := u.Query()
		cb := url.Values{}
		cb.Set("state", q.Get("state")) // par défaut : on réémet le bon state
		for k, v := range params {
			cb[k] = v
		}
		go http.Get("http://127.0.0.1:" + q.Get("port") + "/callback?" + cb.Encode())
	}
}

func TestProvisionHappyPath(t *testing.T) {
	key, err := Provision(context.Background(), "https://auberdine.eu/",
		simulateServer(t, url.Values{"key": {"ak_live_123"}}), nil)
	if err != nil {
		t.Fatalf("Provision: %v", err)
	}
	if key != "ak_live_123" {
		t.Errorf("clé = %q", key)
	}
}

func TestProvisionRejectsBadState(t *testing.T) {
	// Le serveur renvoie un state qui ne correspond pas → refus.
	bad := func(connectURL string) {
		u, _ := url.Parse(connectURL)
		port := u.Query().Get("port")
		go http.Get("http://127.0.0.1:" + port + "/callback?state=WRONG&key=ak_x")
	}
	_, err := Provision(context.Background(), "https://auberdine.eu", bad, nil)
	if err == nil {
		t.Fatal("attendu un refus sur state invalide")
	}
}

func TestProvisionSurfacesServerError(t *testing.T) {
	_, err := Provision(context.Background(), "https://auberdine.eu",
		simulateServer(t, url.Values{"error": {"cancelled"}}), nil)
	if err == nil {
		t.Fatal("attendu une erreur quand le serveur renvoie error=")
	}
}

func TestProvisionContextCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.Sleep(50 * time.Millisecond); cancel() }()
	// onURL ne fait rien : aucun callback n'arrivera → annulation par le contexte.
	_, err := Provision(ctx, "https://auberdine.eu", func(string) {}, nil)
	if err == nil {
		t.Fatal("attendu une annulation par le contexte")
	}
}
