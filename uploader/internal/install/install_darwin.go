//go:build darwin

package install

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// agentLabel identifie le LaunchAgent auprès de launchd.
const agentLabel = "eu.auberdine.uploader"

func stableBinaryPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, "Library", "Application Support", "auberdine-uploader", binaryName), nil
}

func plistPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, "Library", "LaunchAgents", agentLabel+".plist"), nil
}

func logPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Library", "Logs", "auberdine-uploader.log")
}

// Install pose le LaunchAgent et le démarre immédiatement (RunAtLoad).
// mode est "tray" ou "daemon" selon ce que le binaire sait faire.
// LimitLoadToSessionType Aqua : le service ne vit que dans la session
// graphique — indispensable pour l'icône de barre des menus.
func Install(mode string, logger *log.Logger) error {
	bin, err := copySelf()
	if err != nil {
		return err
	}
	pl, err := plistPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(pl), 0o755); err != nil {
		return err
	}

	plist := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>%s</string>
	<key>ProgramArguments</key>
	<array>
		<string>%s</string>
		<string>%s</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<dict>
		<key>SuccessfulExit</key>
		<false/>
	</dict>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>StandardOutPath</key>
	<string>%s</string>
	<key>StandardErrorPath</key>
	<string>%s</string>
</dict>
</plist>
`, agentLabel, bin, mode, logPath(), logPath())

	if err := os.WriteFile(pl, []byte(plist), 0o644); err != nil {
		return err
	}

	// Décharge une éventuelle instance précédente (erreur ignorée : absente à
	// la première installation), puis charge la nouvelle. bootstrap démarre le
	// service tout de suite grâce à RunAtLoad.
	uid := os.Getuid()
	_ = exec.Command("launchctl", "bootout", fmt.Sprintf("gui/%d/%s", uid, agentLabel)).Run()
	out, err := exec.Command("launchctl", "bootstrap", fmt.Sprintf("gui/%d", uid), pl).CombinedOutput()
	if err != nil {
		return fmt.Errorf("install: launchctl bootstrap: %v — %s", err, strings.TrimSpace(string(out)))
	}

	logger.Printf("LaunchAgent installé : %s (mode %s)", pl, mode)
	logger.Printf("binaire : %s", bin)
	logger.Printf("journal : %s", logPath())
	return nil
}

// Uninstall décharge et retire le LaunchAgent ainsi que le binaire installé.
// La configuration et la clé sont conservées.
func Uninstall(logger *log.Logger) error {
	pl, err := plistPath()
	if err != nil {
		return err
	}
	uid := os.Getuid()
	_ = exec.Command("launchctl", "bootout", fmt.Sprintf("gui/%d/%s", uid, agentLabel)).Run()

	removed := false
	if err := os.Remove(pl); err == nil {
		removed = true
	} else if !os.IsNotExist(err) {
		return err
	}
	if bin, err := stableBinaryPath(); err == nil {
		if err := os.Remove(bin); err == nil {
			removed = true
		}
	}
	if !removed {
		logger.Print("rien à désinstaller (service absent)")
		return nil
	}
	logger.Print("LaunchAgent et binaire retirés — configuration et clé conservées")
	return nil
}

// Status renvoie l'état d'installation pour `status` / `doctor`.
func Status() State {
	st := State{}
	pl, err := plistPath()
	if err != nil {
		return st
	}
	st.UnitPath = pl
	if bin, err := stableBinaryPath(); err == nil {
		st.BinPath = bin
	}
	if _, err := os.Stat(pl); err != nil {
		return st
	}
	st.Installed = true
	// launchctl print échoue si le job n'est pas chargé dans la session.
	err = exec.Command("launchctl", "print", fmt.Sprintf("gui/%d/%s", os.Getuid(), agentLabel)).Run()
	if err == nil {
		st.Detail = "chargé dans la session"
	} else {
		st.Detail = "posé mais non chargé (déconnexion/reconnexion ou launchctl bootstrap)"
	}
	return st
}
