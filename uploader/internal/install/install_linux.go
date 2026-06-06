//go:build linux

package install

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const unitName = "auberdine-uploader.service"

func stableBinaryPath() (string, error) {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		dataHome = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(dataHome, "auberdine-uploader", binaryName), nil
}

func unitPath() (string, error) {
	cfgHome := os.Getenv("XDG_CONFIG_HOME")
	if cfgHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		cfgHome = filepath.Join(home, ".config")
	}
	return filepath.Join(cfgHome, "systemd", "user", unitName), nil
}

// Install pose une unité systemd-user et l'active immédiatement.
// Sous Linux le mode par défaut est "daemon" : le tray exige les bibliothèques
// GTK/appindicator au build ET un environnement de bureau au run — quand le
// binaire les a (build -tags tray), mode "tray" est honoré tel quel.
func Install(mode string, logger *log.Logger) error {
	if _, err := exec.LookPath("systemctl"); err != nil {
		return fmt.Errorf("install: systemctl introuvable — installation manuelle requise (lancer « %s daemon » au démarrage de session)", binaryName)
	}
	bin, err := copySelf()
	if err != nil {
		return err
	}
	up, err := unitPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(up), 0o755); err != nil {
		return err
	}

	unit := fmt.Sprintf(`[Unit]
Description=Auberdine Uploader (exports addon + logs de donjon vers auberdine.eu)
After=default.target

[Service]
ExecStart=%s %s
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
`, bin, mode)

	if err := os.WriteFile(up, []byte(unit), 0o644); err != nil {
		return err
	}

	for _, args := range [][]string{
		{"--user", "daemon-reload"},
		{"--user", "enable", "--now", unitName},
	} {
		out, err := exec.Command("systemctl", args...).CombinedOutput()
		if err != nil {
			return fmt.Errorf("install: systemctl %s: %v — %s", strings.Join(args, " "), err, strings.TrimSpace(string(out)))
		}
	}

	logger.Printf("unité systemd-user installée : %s (mode %s)", up, mode)
	logger.Printf("binaire : %s", bin)
	logger.Printf("journal : journalctl --user -u %s", unitName)
	return nil
}

// Uninstall désactive et retire l'unité ainsi que le binaire installé.
// La configuration et la clé sont conservées.
func Uninstall(logger *log.Logger) error {
	up, err := unitPath()
	if err != nil {
		return err
	}
	if _, err := exec.LookPath("systemctl"); err == nil {
		_ = exec.Command("systemctl", "--user", "disable", "--now", unitName).Run()
	}

	removed := false
	if err := os.Remove(up); err == nil {
		removed = true
		if _, lerr := exec.LookPath("systemctl"); lerr == nil {
			_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
		}
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
	logger.Print("unité systemd-user et binaire retirés — configuration et clé conservées")
	return nil
}

// Status renvoie l'état d'installation pour `status` / `doctor`.
func Status() State {
	st := State{}
	up, err := unitPath()
	if err != nil {
		return st
	}
	st.UnitPath = up
	if bin, err := stableBinaryPath(); err == nil {
		st.BinPath = bin
	}
	if _, err := os.Stat(up); err != nil {
		return st
	}
	st.Installed = true
	if err := exec.Command("systemctl", "--user", "is-active", "--quiet", unitName).Run(); err == nil {
		st.Detail = "active"
	} else {
		st.Detail = "posée mais inactive (systemctl --user start " + unitName + ")"
	}
	return st
}
