//go:build linux

package selfupdate

import (
	"os"
	"syscall"
)

// Restart relance le binaire mis à jour (chemin renvoyé par Apply) en
// remplaçant l'image du processus courant : le PID ne change pas, systemd
// (Restart=on-failure) ne voit aucune interruption — et un lancement manuel
// en terminal continue simplement sur la nouvelle version. Pas de piège
// AppKit ici (cf. restart_darwin.go) : le tray Linux passe par D-Bus, qui
// survit à un exec.
func Restart(exe string) error {
	args := append([]string{exe}, os.Args[1:]...)
	return syscall.Exec(exe, args, os.Environ())
}
