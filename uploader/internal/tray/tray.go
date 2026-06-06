//go:build tray

// Package tray fournit l'icône de barre des tâches (état, pause, bascules de
// consentement, quitter). Il n'est compilé qu'avec le build tag `tray` afin que
// le démon par défaut reste sans dépendance externe :
//
//	go build -tags tray ./cmd/auberdine-uploader
//
// Sur Linux, la dépendance systray requiert les bibliothèques système GTK /
// libayatana-appindicator au moment de la compilation.
package tray

import (
	"context"
	_ "embed"
	"log"

	"fyne.io/systray"

	"github.com/yokoul/auberdine-exporter/uploader/internal/app"
	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
)

//go:embed icon.png
var iconData []byte

// Available indique si le support du tray est compilé dans ce binaire.
const Available = true

// Run affiche le tray et lance le démon en arrière-plan. L'appel bloque jusqu'à
// la sortie (clic sur « Quitter » ou annulation du contexte).
func Run(ctx context.Context, a *app.App, _ config.Config, logger *log.Logger) {
	ctx, cancel := context.WithCancel(ctx)

	onReady := func() {
		systray.SetIcon(iconData)
		systray.SetTitle("Auberdine")
		systray.SetTooltip("Auberdine Uploader")

		mStatus := systray.AddMenuItem("Démarrage…", "")
		mStatus.Disable()
		systray.AddSeparator()
		mPause := systray.AddMenuItemCheckbox("Pause", "Suspend toute transmission", a.Paused())
		systray.AddSeparator()
		mExports := systray.AddMenuItemCheckbox("Envoyer les exports", "Transmettre les exports de l'addon", a.UploadExports())
		mDungeons := systray.AddMenuItemCheckbox("Envoyer les logs de donjon", "Transmettre les logs de combat de donjon", a.UploadDungeonLogs())
		systray.AddSeparator()
		mQuit := systray.AddMenuItem("Quitter", "Arrête l'uploader")

		setChecked := func(item *systray.MenuItem, on bool) {
			if on {
				item.Check()
			} else {
				item.Uncheck()
			}
		}
		refresh := func() {
			if a.Paused() {
				mStatus.SetTitle("⏸ En pause")
				mPause.Check()
			} else {
				mStatus.SetTitle("▶ Actif")
				mPause.Uncheck()
			}
			setChecked(mExports, a.UploadExports())
			setChecked(mDungeons, a.UploadDungeonLogs())
		}
		refresh()

		// Lance la surveillance en arrière-plan.
		go func() {
			if err := a.Run(ctx); err != nil && err != context.Canceled {
				logger.Printf("démon arrêté : %v", err)
			}
		}()

		go func() {
			for {
				select {
				case <-ctx.Done():
					systray.Quit()
					return
				case <-mPause.ClickedCh:
					a.SetPaused(!a.Paused())
					refresh()
				case <-mExports.ClickedCh:
					if err := a.SetUploadExports(!a.UploadExports()); err != nil {
						logger.Printf("réglage exports : %v", err)
					}
					refresh()
				case <-mDungeons.ClickedCh:
					if err := a.SetUploadDungeonLogs(!a.UploadDungeonLogs()); err != nil {
						logger.Printf("réglage logs donjon : %v", err)
					}
					refresh()
				case <-mQuit.ClickedCh:
					cancel()
					systray.Quit()
					return
				}
			}
		}()
	}

	onExit := func() { cancel() }

	systray.Run(onReady, onExit)
}
