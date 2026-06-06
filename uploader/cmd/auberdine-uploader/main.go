// Commande auberdine-uploader : démon léger qui transmet les exports de
// l'addon et les segments de log de combat de donjon vers auberdine.eu.
//
// Sous-commandes :
//
//	auberdine-uploader daemon   Lance la surveillance (défaut)
//	auberdine-uploader status   Affiche l'état (chemins, config, identité)
//	auberdine-uploader doctor   Diagnostique la détection des fichiers
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"log"

	"github.com/yokoul/auberdine-exporter/uploader/internal/app"
	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/connect"
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
	"github.com/yokoul/auberdine-exporter/uploader/internal/install"
	"github.com/yokoul/auberdine-exporter/uploader/internal/tray"
)

func main() {
	cmd := "daemon"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}

	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config: %v\n", err)
		os.Exit(1)
	}

	switch cmd {
	case "daemon":
		runDaemon(cfg)
	case "tray":
		runTray(cfg)
	case "connect":
		runConnect(cfg)
	case "status":
		runStatus(cfg)
	case "doctor":
		runDoctor(cfg)
	case "install":
		runInstall()
	case "uninstall":
		runUninstall()
	case "-h", "--help", "help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "commande inconnue: %s\n\n", cmd)
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Print(`auberdine-uploader — transmet exports et logs de donjon vers auberdine.eu

Usage:
  auberdine-uploader [daemon]   Lance la surveillance (défaut)
  auberdine-uploader tray       Lance la surveillance avec l'icône de barre des tâches
  auberdine-uploader connect    Connecte l'uploader à auberdine.eu (ouvre le navigateur)
  auberdine-uploader status     Affiche l'état courant
  auberdine-uploader doctor     Diagnostique la détection des fichiers
  auberdine-uploader install    Installe le service utilisateur (démarre à l'ouverture de session)
  auberdine-uploader uninstall  Retire le service utilisateur (conserve config et clé)

Le tray nécessite un binaire compilé avec -tags tray ; install lance le tray
si le binaire le permet, le démon sinon.
`)
}

func runTray(cfg config.Config) {
	logger := log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	if !tray.Available {
		logger.Print("tray indisponible : recompilez avec « go build -tags tray ./cmd/auberdine-uploader »")
		os.Exit(1)
	}
	a, err := app.New(cfg, nil, logger)
	if err != nil {
		fmt.Fprintf(os.Stderr, "démarrage: %v\n", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	tray.Run(ctx, a, cfg, logger)
}

func runDaemon(cfg config.Config) {
	a, err := app.New(cfg, nil, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "démarrage: %v\n", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := a.Run(ctx); err != nil && err != context.Canceled {
		fmt.Fprintf(os.Stderr, "arrêt: %v\n", err)
	}
}

func runConnect(cfg config.Config) {
	logger := log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	fmt.Println("Ouverture du navigateur pour la connexion à auberdine.eu…")
	key, err := connect.Provision(ctx, cfg.Endpoint, func(u string) {
		if err := connect.OpenBrowser(u); err != nil {
			fmt.Printf("Impossible d'ouvrir le navigateur. Ouvrez ce lien manuellement :\n  %s\n", u)
		}
	}, logger)
	if err != nil {
		fmt.Fprintf(os.Stderr, "connexion: %v\n", err)
		os.Exit(1)
	}
	cfg.APIKey = key
	if err := cfg.Save(); err != nil {
		fmt.Fprintf(os.Stderr, "enregistrement de la clé: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Connecté à auberdine.eu ✅ La clé a été enregistrée.")
}

func runStatus(cfg config.Config) {
	p, _ := config.Path()
	fmt.Printf("Config        : %s\n", p)
	fmt.Printf("Endpoint      : %s\n", orNone(cfg.Endpoint))
	fmt.Printf("Exports       : %v\n", cfg.UploadExports)
	fmt.Printf("Logs donjon   : %v\n", cfg.UploadDungeonLogs)
	if cfg.HasAPIKey() {
		fmt.Printf("Clé API       : configurée (%s)\n", maskKey(cfg.APIKey))
	} else {
		fmt.Printf("Clé API       : absente (renseignez apiKey)\n")
	}
	paths, ok := discovery.Detect(cfg.WoWPath)
	if !ok {
		fmt.Printf("WoW           : introuvable (configurez wowPath)\n")
		return
	}
	fmt.Printf("WoW           : %s\n", paths.VersionDir)
	fmt.Printf("SavedVariables: %d fichier(s)\n", len(paths.SavedVars))
}

func runDoctor(cfg config.Config) {
	paths, ok := discovery.Detect(cfg.WoWPath)
	if !ok {
		fmt.Println("✗ Installation WoW Classic Era introuvable.")
		fmt.Println("  → Renseignez wowPath dans la configuration.")
		os.Exit(1)
	}
	fmt.Printf("✓ Dossier de version : %s\n", paths.VersionDir)
	if len(paths.SavedVars) == 0 {
		fmt.Println("✗ Aucun AuberdineExporter.lua trouvé (l'addon a-t-il déjà tourné ?)")
	} else {
		for _, sv := range paths.SavedVars {
			fmt.Printf("✓ SavedVariables : %s\n", sv)
		}
	}
	logs := discovery.ListCombatLogs(paths.LogsDir)
	if len(logs) == 0 {
		fmt.Printf("• Logs de combat : aucun dans %s (créés en jeu, un par session de logging)\n", paths.LogsDir)
	} else {
		for i, l := range logs {
			if i >= 3 {
				fmt.Printf("✓ Logs de combat : … et %d autre(s)\n", len(logs)-3)
				break
			}
			fmt.Printf("✓ Log de combat  : %s\n", l.Path)
		}
	}
	if st := install.Status(); st.Installed {
		fmt.Printf("✓ Service        : %s (%s)\n", st.UnitPath, st.Detail)
	} else {
		fmt.Printf("• Service        : non installé (« auberdine-uploader install »)\n")
	}
}

// runInstall pose le service utilisateur. Le mode suit le binaire : tray si
// compilé avec -tags tray (icône de barre des tâches), démon discret sinon.
func runInstall() {
	logger := log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	mode := "daemon"
	if tray.Available {
		mode = "tray"
	}
	if err := install.Install(mode, logger); err != nil {
		fmt.Fprintf(os.Stderr, "installation: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Service installé — l'uploader démarre maintenant et à chaque ouverture de session.")
}

func runUninstall() {
	logger := log.New(os.Stderr, "auberdine-uploader ", log.LstdFlags)
	if err := install.Uninstall(logger); err != nil {
		fmt.Fprintf(os.Stderr, "désinstallation: %v\n", err)
		os.Exit(1)
	}
}

func orNone(s string) string {
	if s == "" {
		return "(non configuré)"
	}
	return s
}

// maskKey masque une clé API pour l'affichage (ne révèle que le préfixe).
func maskKey(k string) string {
	if len(k) <= 6 {
		return "ak_…"
	}
	return k[:6] + "…"
}
