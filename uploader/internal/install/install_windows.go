//go:build windows

package install

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

// runKey est la clé de démarrage automatique par utilisateur (aucune élévation).
const (
	runKey   = `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
	runValue = "AuberdineUploader"
)

func stableBinaryPath() (string, error) {
	local := os.Getenv("LOCALAPPDATA")
	if local == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		local = filepath.Join(home, "AppData", "Local")
	}
	return filepath.Join(local, "auberdine-uploader", binaryName+".exe"), nil
}

// Install enregistre le démarrage automatique à l'ouverture de session via la
// clé Run du registre (posée avec reg.exe — pas de dépendance Go externe),
// puis lance le service immédiatement.
func Install(mode string, logger *log.Logger) error {
	bin, err := copySelf()
	if err != nil {
		return err
	}

	cmdLine := fmt.Sprintf(`"%s" %s`, bin, mode)
	out, err := exec.Command("reg", "add", runKey, "/v", runValue, "/t", "REG_SZ", "/d", cmdLine, "/f").CombinedOutput()
	if err != nil {
		return fmt.Errorf("install: reg add: %v — %s", err, strings.TrimSpace(string(out)))
	}

	// Démarre tout de suite (la clé Run ne jouera qu'à la prochaine session).
	// DETACHED_PROCESS est indispensable : lancé en simple enfant, le tray
	// hériterait de la console et son AttachConsole (console_windows.go) le
	// rattacherait à la fenêtre PowerShell — fermer le terminal le tuerait
	// (CTRL_CLOSE), observé au premier install Windows réel. Détaché, il n'a
	// aucune console parente et survit à la fermeture du terminal.
	const detachedProcess = 0x00000008
	const createNewProcessGroup = 0x00000200
	cmd := exec.Command(bin, mode)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: detachedProcess | createNewProcessGroup,
	}
	if err := cmd.Start(); err != nil {
		logger.Printf("démarrage immédiat impossible (%v) — il démarrera à la prochaine session", err)
	}

	logger.Printf("démarrage automatique enregistré : %s\\%s (mode %s)", runKey, runValue, mode)
	logger.Printf("binaire : %s", bin)
	return nil
}

// Uninstall retire la clé de démarrage et le binaire installé.
// La configuration et la clé d'API sont conservées.
func Uninstall(logger *log.Logger) error {
	removed := false
	if err := exec.Command("reg", "delete", runKey, "/v", runValue, "/f").Run(); err == nil {
		removed = true
	}
	if bin, err := stableBinaryPath(); err == nil {
		// Sous Windows un binaire en cours d'exécution ne peut pas être
		// supprimé : signaler plutôt qu'échouer.
		if err := os.Remove(bin); err == nil {
			removed = true
		} else if !os.IsNotExist(err) {
			logger.Printf("binaire encore en cours d'exécution ? à retirer manuellement : %s", bin)
		}
	}
	if !removed {
		logger.Print("rien à désinstaller (démarrage automatique absent)")
		return nil
	}
	logger.Print("démarrage automatique retiré — configuration et clé conservées")
	return nil
}

// Status renvoie l'état d'installation pour `status` / `doctor`.
func Status() State {
	st := State{UnitPath: runKey + `\` + runValue}
	if bin, err := stableBinaryPath(); err == nil {
		st.BinPath = bin
	}
	if err := exec.Command("reg", "query", runKey, "/v", runValue).Run(); err == nil {
		st.Installed = true
		st.Detail = "clé Run posée (démarre à l'ouverture de session)"
	}
	return st
}
