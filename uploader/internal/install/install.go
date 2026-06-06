// Package install pose (ou retire) l'uploader en service utilisateur :
// démarré à l'ouverture de session, relancé en cas d'arrêt anormal. Aucune
// élévation de privilèges : tout vit dans le profil de l'utilisateur.
//
//   - macOS   : LaunchAgent ~/Library/LaunchAgents/eu.auberdine.uploader.plist
//   - Linux   : unité systemd-user ~/.config/systemd/user/auberdine-uploader.service
//   - Windows : valeur de registre HKCU\...\Run (posée via reg.exe)
//
// Le binaire courant est d'abord copié vers un emplacement stable du profil
// (copySelf) — on peut donc installer depuis /tmp ou un dossier de
// téléchargement sans laisser le service pointer sur un chemin volatil.
//
// La désinstallation retire le service et le binaire copié, mais conserve la
// configuration et la clé (~/.config|Application Support/auberdine-uploader) :
// réinstaller plus tard ne demande pas de refaire `connect`.
package install

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// binaryName est le nom du binaire installé (suffixe .exe ajouté sous Windows).
const binaryName = "auberdine-uploader"

// State décrit l'installation courante pour `status` / `doctor`.
type State struct {
	Installed bool   // service utilisateur posé
	UnitPath  string // chemin du plist / unit / clé de registre
	BinPath   string // chemin du binaire installé
	Detail    string // information complémentaire (chargé, mode, …)
}

// copySelf copie le binaire courant vers l'emplacement stable du profil et
// renvoie ce chemin. Si le binaire courant est déjà l'installé, rien à faire.
func copySelf() (string, error) {
	src, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("install: binaire courant introuvable: %w", err)
	}
	src, err = filepath.EvalSymlinks(src)
	if err != nil {
		return "", err
	}

	dest, err := stableBinaryPath()
	if err != nil {
		return "", err
	}
	if src == dest {
		return dest, nil
	}

	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return "", err
	}
	in, err := os.Open(src)
	if err != nil {
		return "", err
	}
	defer in.Close()

	// Écriture via un fichier temporaire puis rename : remplace proprement un
	// binaire installé encore en cours d'exécution (Unix) et évite les copies
	// tronquées en cas d'interruption.
	tmp := dest + ".new"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		os.Remove(tmp)
		return "", err
	}
	if err := out.Close(); err != nil {
		os.Remove(tmp)
		return "", err
	}
	if err := os.Rename(tmp, dest); err != nil {
		os.Remove(tmp)
		return "", err
	}
	return dest, nil
}
