//go:build !windows

package selfupdate

import (
	"os"
	"syscall"
)

// Restart relance le binaire mis à jour (chemin renvoyé par Apply) en
// remplaçant l'image du processus courant : le PID ne change pas, launchd
// (KeepAlive) et systemd (Restart=) ne voient aucune interruption — et un
// lancement manuel en terminal continue simplement sur la nouvelle version.
func Restart(exe string) error {
	args := append([]string{exe}, os.Args[1:]...)
	return syscall.Exec(exe, args, os.Environ())
}
