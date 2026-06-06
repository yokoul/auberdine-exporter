// Package connect provisionne la clé d'ingestion sans CLI ni copier-coller, via
// le navigateur : c'est le pattern loopback des applications natives (RFC 8252).
//
// Le client démarre un petit serveur sur 127.0.0.1:<port aléatoire>, ouvre le
// navigateur sur la page de connexion d'auberdine.eu (authentifiée par le cookie
// Discord du site), et le site redirige la clé fraîche vers
// http://127.0.0.1:<port>/callback?key=ak_…&state=…. Le site reste l'autorité ;
// le client ne manipule jamais Discord directement.
package connect

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"net"
	"net/http"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// CallbackTimeout borne l'attente de la redirection du site.
const CallbackTimeout = 3 * time.Minute

// Provision exécute le handshake loopback et renvoie la clé ak_ obtenue.
//
// onURL reçoit l'URL de connexion à présenter à l'utilisateur (typiquement :
// ouvrir le navigateur dessus). Elle est séparée pour rester testable et pour
// permettre un repli « copiez ce lien » sur les machines sans navigateur.
func Provision(ctx context.Context, baseURL string, onURL func(connectURL string), logger *log.Logger) (string, error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", fmt.Errorf("connect: écoute loopback impossible: %w", err)
	}
	defer ln.Close()
	port := ln.Addr().(*net.TCPAddr).Port

	state, err := randomState()
	if err != nil {
		return "", err
	}

	keyCh := make(chan string, 1)
	errCh := make(chan error, 1)

	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("state") != state {
			writePage(w, http.StatusBadRequest, "Lien de connexion invalide ou expiré. Relancez la connexion depuis l'uploader.")
			select {
			case errCh <- fmt.Errorf("connect: state invalide"):
			default:
			}
			return
		}
		if e := q.Get("error"); e != "" {
			writePage(w, http.StatusOK, "Connexion annulée. Vous pouvez fermer cet onglet et réessayer depuis l'uploader.")
			select {
			case errCh <- fmt.Errorf("connect: refusé par le serveur (%s)", e):
			default:
			}
			return
		}
		key := q.Get("key")
		if !strings.HasPrefix(key, "ak_") {
			writePage(w, http.StatusBadRequest, "Réponse inattendue du serveur (clé absente).")
			select {
			case errCh <- fmt.Errorf("connect: clé absente dans la réponse"):
			default:
			}
			return
		}
		writePage(w, http.StatusOK, "Uploader connecté à auberdine.eu ✅ Vous pouvez fermer cet onglet.")
		select {
		case keyCh <- key:
		default:
		}
	})

	srv := &http.Server{Handler: mux}
	go srv.Serve(ln)
	defer srv.Close()

	connectURL := fmt.Sprintf("%s/uploader/connect?port=%d&state=%s", strings.TrimRight(baseURL, "/"), port, state)
	if onURL != nil {
		onURL(connectURL)
	}
	if logger != nil {
		logger.Printf("en attente de la connexion… si le navigateur ne s'ouvre pas, ouvrez : %s", connectURL)
	}

	select {
	case key := <-keyCh:
		return key, nil
	case err := <-errCh:
		return "", err
	case <-time.After(CallbackTimeout):
		return "", fmt.Errorf("connect: délai dépassé (aucune réponse du navigateur)")
	case <-ctx.Done():
		return "", ctx.Err()
	}
}

// randomState génère un nonce anti-CSRF à usage unique.
func randomState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("connect: génération du state: %w", err)
	}
	return hex.EncodeToString(b), nil
}

func writePage(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	fmt.Fprintf(w, `<!doctype html><html lang="fr"><head><meta charset="utf-8">`+
		`<title>Auberdine Uploader</title></head>`+
		`<body style="font-family:sans-serif;text-align:center;padding:3rem;color:#222">`+
		`<h2>%s</h2></body></html>`, msg)
}

// OpenBrowser ouvre une URL dans le navigateur par défaut, selon l'OS.
func OpenBrowser(url string) error {
	var cmd string
	var args []string
	switch runtime.GOOS {
	case "windows":
		cmd, args = "rundll32", []string{"url.dll,FileProtocolHandler", url}
	case "darwin":
		cmd, args = "open", []string{url}
	default:
		cmd, args = "xdg-open", []string{url}
	}
	return exec.Command(cmd, args...).Start()
}
