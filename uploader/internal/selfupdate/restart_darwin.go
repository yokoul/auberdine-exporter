//go:build darwin

package selfupdate

import (
	"fmt"
	"os"
)

// Restart termine le processus en échec contrôlé pour que launchd relance le
// binaire mis à jour (KeepAlive SuccessfulExit=false dans le plist).
//
// Surtout PAS de syscall.Exec ici : une app AppKit/Cocoa (le tray) ne survit
// pas à un exec sans fork — la connexion au WindowServer est invalidée, le
// démon repart mais l'icône de barre des menus ne se recrée jamais (vécu sur
// la mise à jour v0.2.0 → v0.2.1). Le cycle launchd, lui, repart d'un
// processus tout neuf, AppKit compris.
//
// Lancé manuellement en terminal (hors launchd), le processus se termine
// simplement : à l'utilisateur de relancer — cas marginal, l'installation
// standard passe par le LaunchAgent.
func Restart(exe string) error {
	fmt.Fprintf(os.Stderr, "auberdine-uploader: binaire mis à jour (%s), arrêt pour relance par launchd\n", exe)
	os.Exit(1)
	return nil // jamais atteint
}
