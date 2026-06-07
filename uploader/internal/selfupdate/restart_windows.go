//go:build windows

package selfupdate

import (
	"os"
	"os/exec"
	"syscall"
)

// Restart lance le binaire mis à jour (chemin renvoyé par Apply) en processus
// détaché puis termine le processus courant. Pas de superviseur sous Windows
// (clé Run utilisateur) : c'est au mourant d'allumer son successeur. Mêmes
// précautions que install_windows.go : DETACHED_PROCESS pour survivre à toute
// console parente, AUBERDINE_UPLOADER_NO_CONSOLE pour interdire
// l'AttachConsole du successeur.
func Restart(exe string) error {
	const detachedProcess = 0x00000008
	const createNewProcessGroup = 0x00000200
	cmd := exec.Command(exe, os.Args[1:]...)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: detachedProcess | createNewProcessGroup,
	}
	cmd.Env = append(os.Environ(), "AUBERDINE_UPLOADER_NO_CONSOLE=1")
	if err := cmd.Start(); err != nil {
		return err
	}
	os.Exit(0)
	return nil // jamais atteint
}
