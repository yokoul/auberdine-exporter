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
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
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
	case "status":
		runStatus(cfg)
	case "doctor":
		runDoctor(cfg)
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
  auberdine-uploader status     Affiche l'état courant
  auberdine-uploader doctor     Diagnostique la détection des fichiers

Le tray nécessite un binaire compilé avec -tags tray.
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

func runStatus(cfg config.Config) {
	p, _ := config.Path()
	fmt.Printf("Config        : %s\n", p)
	fmt.Printf("Endpoint      : %s\n", orNone(cfg.Endpoint))
	fmt.Printf("Exports       : %v\n", cfg.UploadExports)
	fmt.Printf("Logs donjon   : %v\n", cfg.UploadDungeonLogs)
	if cfg.LoggedIn() {
		fmt.Printf("Discord       : connecté (%s)\n", cfg.Discord.Username)
	} else {
		fmt.Printf("Discord       : non connecté\n")
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
	if _, err := os.Stat(paths.CombatLog); err == nil {
		fmt.Printf("✓ Log de combat  : %s\n", paths.CombatLog)
	} else {
		fmt.Printf("• Log de combat  : %s (absent — activé seulement en jeu)\n", paths.CombatLog)
	}
}

func orNone(s string) string {
	if s == "" {
		return "(non configuré)"
	}
	return s
}
