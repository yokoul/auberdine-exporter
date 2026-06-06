// Package auth gère l'identité Discord associée aux publications.
//
// Le flux OAuth complet (login navigateur + redirection loopback) est volontairement
// différé : c'est la même mécanique que sur auberdine.eu et il sera branché dans
// un second temps. En attendant, l'essentiel est en place : pouvoir se délier
// (logout) et joindre l'identifiant Discord aux envois pour le recoupement.
package auth

import (
	"fmt"
	"os/exec"
	"runtime"

	"github.com/yokoul/auberdine-exporter/uploader/internal/app"
	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
)

// Logout efface l'identité Discord et la persiste.
func Logout(a *app.App) error {
	return a.SetDiscord(config.DiscordIdentity{})
}

// Login déclenche la liaison du compte Discord. Tant que le flux OAuth n'est pas
// implémenté, on ouvre la page de liaison auberdine.eu dans le navigateur si une
// URL est configurée, sinon on renvoie une erreur explicite.
func Login(a *app.App, authorizeURL string) error {
	if authorizeURL == "" {
		return fmt.Errorf("login Discord : flux OAuth pas encore configuré (authorizeURL vide)")
	}
	return openBrowser(authorizeURL)
}

// openBrowser ouvre une URL dans le navigateur par défaut, selon l'OS.
func openBrowser(url string) error {
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
