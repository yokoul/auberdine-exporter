//go:build !windows

// Hors Windows, les logs vont sur stderr — le superviseur (LaunchAgent macOS,
// systemd Linux) les redirige déjà vers un fichier. Pas de tee maison.
package main

import (
	"io"
	"os"
)

func logWriter() io.Writer { return os.Stderr }
