//go:build tray

// Package tray fournit l'icône de barre des tâches (quit / pause / login /
// logout Discord). Il n'est compilé qu'avec le build tag `tray` afin que le
// démon par défaut reste sans dépendance externe :
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
	"github.com/yokoul/auberdine-exporter/uploader/internal/auth"
	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
)

//go:embed icon.png
var iconData []byte

// Available indique si le support du tray est compilé dans ce binaire.
const Available = true

// Run affiche le tray et lance le démon en arrière-plan. L'appel bloque jusqu'à
// la sortie (clic sur « Quitter » ou annulation du contexte).
func Run(ctx context.Context, a *app.App, cfg config.Config, logger *log.Logger) {
	ctx, cancel := context.WithCancel(ctx)

	onReady := func() {
		systray.SetIcon(iconData)
		systray.SetTitle("Auberdine")
		systray.SetTooltip("Auberdine Uploader")

		mStatus := systray.AddMenuItem("Démarrage…", "")
		mStatus.Disable()
		systray.AddSeparator()
		mPause := systray.AddMenuItemCheckbox("Pause", "Suspend la transmission", a.Paused())
		systray.AddSeparator()
		mDiscord := systray.AddMenuItem("", "")
		systray.AddSeparator()
		mQuit := systray.AddMenuItem("Quitter", "Arrête l'uploader")

		refresh := func() {
			if a.Paused() {
				mStatus.SetTitle("⏸ En pause")
				mPause.Check()
			} else {
				mStatus.SetTitle("▶ Actif")
				mPause.Uncheck()
			}
			if a.LoggedIn() {
				name := a.DiscordUsername()
				if name == "" {
					name = "compte lié"
				}
				mDiscord.SetTitle("Se déconnecter de Discord (" + name + ")")
			} else {
				mDiscord.SetTitle("Se connecter à Discord")
			}
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
				case <-mDiscord.ClickedCh:
					if a.LoggedIn() {
						if err := auth.Logout(a); err != nil {
							logger.Printf("logout : %v", err)
						}
					} else {
						if err := auth.Login(a, cfg.DiscordAuthorizeURL); err != nil {
							logger.Printf("login : %v", err)
						}
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
