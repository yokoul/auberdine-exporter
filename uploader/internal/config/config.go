// Package config gère la configuration persistante de l'uploader.
//
// La configuration vit dans le répertoire de config utilisateur standard
// (XDG_CONFIG_HOME sur Linux/macOS, %AppData% sur Windows) et reste minimale :
// chemins WoW (auto-détectés mais surchargeables), endpoint d'ingestion et
// clé API auberdine.eu (scope ingest:upload).
package config

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/yokoul/auberdine-exporter/uploader/internal/atomicfile"
)

// DefaultEndpoint est la base de l'API d'ingestion auberdine.eu.
const DefaultEndpoint = "https://auberdine.eu"

// Config est l'état configurable de l'uploader.
type Config struct {
	// WoWPath pointe vers le dossier de version (ex. ".../_classic_era_").
	// Vide => auto-détection au démarrage.
	WoWPath string `json:"wowPath,omitempty"`

	// Endpoint est la base de l'API d'ingestion auberdine.eu.
	Endpoint string `json:"endpoint"`

	// APIKey est la clé d'ingestion (préfixe ak_, scope ingest:upload). Elle
	// porte le discord_id côté serveur (auto-claim des personnages). Envoyée en
	// Authorization: Bearer. À créer via /admin/apiaccess (ou scripts/api-key.js).
	APIKey string `json:"apiKey"`

	// Upload active/désactive chaque flux (consentement granulaire, modifiable
	// à chaud depuis le tray).
	UploadExports     bool `json:"uploadExports"`
	UploadDungeonLogs bool `json:"uploadDungeonLogs"`

	// PollInterval est l'intervalle de scan des fichiers, en secondes.
	PollIntervalSeconds int `json:"pollIntervalSeconds"`

	// DisableAutoUpdate désactive la mise à jour automatique du binaire
	// (annoncée par le serveur via /ingest/status). Actif par défaut.
	DisableAutoUpdate bool `json:"disableAutoUpdate,omitempty"`
}

// HasAPIKey indique si une clé d'ingestion est configurée.
func (c *Config) HasAPIKey() bool { return c.APIKey != "" }

// Default renvoie une configuration aux valeurs par défaut raisonnables.
func Default() Config {
	return Config{
		Endpoint:            DefaultEndpoint,
		UploadExports:       true,
		UploadDungeonLogs:   true,
		PollIntervalSeconds: 5,
	}
}

// profileSuffix renvoie le suffixe de fichier selon AUBERDINE_PROFILE, pour
// isoler des configurations indépendantes (prod vs dev), chacune avec son
// propre endpoint et sa propre clé API. Vide / "prod" / "production" /
// "default" → config.json. Tout autre nom → config.<profil>.json
// (ex. AUBERDINE_PROFILE=dev → config.dev.json).
func profileSuffix() string {
	p := strings.ToLower(strings.TrimSpace(os.Getenv("AUBERDINE_PROFILE")))
	switch p {
	case "", "prod", "production", "default":
		return ""
	default:
		// On garde le nom tel que saisi (minuscules), nettoyé des séparateurs
		// de chemin pour éviter toute évasion de répertoire.
		safe := strings.NewReplacer("/", "", "\\", "", "..", "").Replace(p)
		return "." + safe
	}
}

// Profile renvoie le nom du profil actif ("prod" par défaut).
func Profile() string {
	if s := profileSuffix(); s != "" {
		return strings.TrimPrefix(s, ".")
	}
	return "prod"
}

// Path renvoie le chemin du fichier de configuration du profil courant.
func Path() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "auberdine-uploader", "config"+profileSuffix()+".json"), nil
}

// Load lit la configuration du profil courant depuis le disque. Si le fichier
// n'existe pas, les valeurs par défaut sont renvoyées sans erreur. La variable
// AUBERDINE_ENDPOINT surcharge l'endpoint (pratique pour pointer un dev local
// sans éditer le fichier ; persistée au prochain `connect`).
func Load() (Config, error) {
	p, err := Path()
	if err != nil {
		return Config{}, err
	}
	cfg := Default()
	data, err := os.ReadFile(p)
	if err == nil {
		if uerr := json.Unmarshal(data, &cfg); uerr != nil {
			// Config corrompue — typiquement une écriture interrompue par un
			// arrêt brutal (l'ancien os.WriteFile tronquait avant d'écrire).
			// NON FATAL : on écarte le fichier abîmé (conservé en .corrupt pour
			// récupérer la clé manuellement au besoin) et on repart des défauts,
			// plutôt que d'empêcher le client de démarrer. L'utilisateur pourra
			// refaire `connect`. Mieux vaut un client qui tourne et redemande la
			// liaison qu'un client mort et silencieux.
			_ = os.Rename(p, p+".corrupt")
			cfg = Default()
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return Config{}, err
	}
	if cfg.Endpoint == "" {
		cfg.Endpoint = DefaultEndpoint
	}
	if ep := strings.TrimSpace(os.Getenv("AUBERDINE_ENDPOINT")); ep != "" {
		cfg.Endpoint = ep
	}
	return cfg, nil
}

// Save écrit la configuration sur le disque (création du dossier au besoin).
func (c *Config) Save() error {
	p, err := Path()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return atomicfile.Write(p, data, 0o600)
}
