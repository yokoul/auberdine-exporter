//go:build windows

// Sur Windows, le service tray est compilé -H windowsgui et lancé par la clé
// Run SANS console (cf. console_windows.go) : ses erreurs, panics et os.Exit
// sont totalement invisibles. Toute panne au démarrage devenait alors
// indiagnosticable (incident legioul). On tee donc les logs vers un fichier
// persistant, à côté de state.json (%LOCALAPPDATA%\auberdine-uploader\).
package main

import (
	"io"
	"os"
	"path/filepath"
	"sync"
)

var (
	logOnce sync.Once
	logOut  io.Writer = os.Stderr
)

// logWriter renvoie la destination des logs : stderr ET un fichier
// %LOCALAPPDATA%\auberdine-uploader\uploader.log (append). Mémoïsé : un seul
// handle de fichier pour tout le process. Si le fichier ne peut être ouvert,
// on retombe sur le seul stderr.
func logWriter() io.Writer {
	logOnce.Do(func() {
		dir, err := os.UserCacheDir() // %LOCALAPPDATA% sous Windows
		if err != nil {
			return
		}
		dir = filepath.Join(dir, "auberdine-uploader")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return
		}
		f, err := os.OpenFile(filepath.Join(dir, "uploader.log"),
			os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
		if err != nil {
			return
		}
		logOut = io.MultiWriter(os.Stderr, f)
	})
	return logOut
}
