//go:build !tray

// Build par défaut (sans le tag `tray`) : pas d'icône de barre des tâches, donc
// aucune dépendance externe. Run signale simplement que le binaire courant n'a
// pas été compilé avec le support du tray.
package tray

import (
	"context"
	"log"

	"github.com/yokoul/auberdine-exporter/uploader/internal/app"
	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
)

// Available indique si le support du tray est compilé dans ce binaire.
const Available = false

// Run n'est pas disponible dans ce build : compiler avec `-tags tray`.
func Run(_ context.Context, _ *app.App, _ config.Config, logger *log.Logger) {
	logger.Print("tray non disponible : binaire compilé sans le tag 'tray' (recompiler avec -tags tray)")
}
