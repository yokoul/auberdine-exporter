// Package config gère la configuration persistante de l'uploader.
//
// La configuration vit dans le répertoire de config utilisateur standard
// (XDG_CONFIG_HOME sur Linux/macOS, %AppData% sur Windows) et reste minimale :
// chemins WoW (auto-détectés mais surchargeables), endpoint d'ingestion et
// jeton d'identité Discord.
package config

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

// Config est l'état configurable de l'uploader.
type Config struct {
	// WoWPath pointe vers le dossier de version (ex. ".../_classic_era_").
	// Vide => auto-détection au démarrage.
	WoWPath string `json:"wowPath,omitempty"`

	// Endpoint est la base de l'API d'ingestion auberdine.eu.
	// À remplir lorsque le contrat serveur est figé.
	Endpoint string `json:"endpoint"`

	// Upload active/désactive chaque flux (consentement granulaire).
	UploadExports    bool `json:"uploadExports"`
	UploadDungeonLogs bool `json:"uploadDungeonLogs"`

	// PollInterval est l'intervalle de scan des fichiers, en secondes.
	PollIntervalSeconds int `json:"pollIntervalSeconds"`

	// Discord contient l'identité obtenue via OAuth (rempli après login).
	Discord DiscordIdentity `json:"discord"`
}

// DiscordIdentity stocke le minimum pour s'authentifier auprès d'auberdine.eu.
type DiscordIdentity struct {
	UserID       string `json:"userId,omitempty"`
	Username     string `json:"username,omitempty"`
	AccessToken  string `json:"accessToken,omitempty"`
	RefreshToken string `json:"refreshToken,omitempty"`
	ExpiresAt    int64  `json:"expiresAt,omitempty"`
}

// LoggedIn indique si une identité Discord exploitable est présente.
func (c *Config) LoggedIn() bool { return c.Discord.AccessToken != "" }

// Default renvoie une configuration aux valeurs par défaut raisonnables.
func Default() Config {
	return Config{
		Endpoint:            "",
		UploadExports:       true,
		UploadDungeonLogs:   true,
		PollIntervalSeconds: 5,
	}
}

// Path renvoie le chemin du fichier de configuration.
func Path() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "auberdine-uploader", "config.json"), nil
}

// Load lit la configuration depuis le disque. Si le fichier n'existe pas, les
// valeurs par défaut sont renvoyées sans erreur.
func Load() (Config, error) {
	p, err := Path()
	if err != nil {
		return Config{}, err
	}
	data, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return Default(), nil
	}
	if err != nil {
		return Config{}, err
	}
	cfg := Default()
	if err := json.Unmarshal(data, &cfg); err != nil {
		return Config{}, err
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
	return os.WriteFile(p, data, 0o600)
}
