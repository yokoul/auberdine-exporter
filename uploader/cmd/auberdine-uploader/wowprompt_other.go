//go:build !windows

package main

import (
	"log"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
)

// promptWoWPath n'existe que sous Windows (binaire GUI sans console, échec
// sinon invisible). Sur macOS/Linux le lancement se fait depuis un terminal :
// le message d'erreur — qui indique le fichier de config — suffit.
func promptWoWPath(cfg *config.Config, logger *log.Logger) bool {
	_ = cfg
	_ = logger
	return false
}
