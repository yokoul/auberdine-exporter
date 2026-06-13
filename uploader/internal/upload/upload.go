// Package upload transmet les données à auberdine.eu via l'API d'ingestion
// (contrat /ingest v1, cf. docs ingest-api.md côté serveur).
//
// Le transport réel est masqué derrière l'interface Uploader afin que le reste
// du démon ne dépende pas du contrat HTTP précis. L'implémentation HTTP
// s'authentifie par clé API (Authorization: Bearer ak_…), applique un retry à
// backoff exponentiel sur les erreurs transitoires (réseau, 429, 5xx) et
// distingue les erreurs définitives (4xx) qu'il ne faut pas retenter.
package upload

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/version"
)

// ClientVersion identifie le client dans les métadonnées d'upload (version
// réelle du binaire, injectée au build — "dev" sur un build local).
var ClientVersion = version.Version

const clientName = "auberdine-uploader"

// Uploader transmet exports et segments de log de donjon.
type Uploader interface {
	// Status réalise le handshake /ingest/status (valide la clé, expose le lien Discord).
	Status(ctx context.Context) (StatusResponse, error)
	// SendExport transmet l'export signé de l'addon (chaîne JSON produite par l'addon).
	SendExport(ctx context.Context, jsonData string) (ExportResult, error)
	// SendDungeonLog transmet un segment de log de combat pour un run de donjon.
	SendDungeonLog(ctx context.Context, meta CombatMeta, raw []byte) (CombatResult, error)
}

// StatusResponse est la réponse de GET /ingest/status.
type StatusResponse struct {
	Success         bool `json:"success"`
	ContractVersion int  `json:"contractVersion"`
	ExportAvailable bool `json:"exportAvailable"`
	Partner         struct {
		Label         string   `json:"label"`
		Scopes        []string `json:"scopes"`
		LinkedDiscord bool     `json:"linkedDiscord"`
		RateLimit     int      `json:"rateLimit"`
	} `json:"partner"`
	// Client décrit la release courante de l'uploader telle que vue par le
	// serveur (pilote la mise à jour automatique). Absent sur un serveur qui
	// ne la publie pas encore : l'auto-update est alors simplement inactif.
	Client *ClientRelease `json:"client,omitempty"`
}

// ClientRelease décrit la dernière release publiée de l'uploader.
type ClientRelease struct {
	Latest       string                  `json:"latest"`       // tag, ex. "v0.2.0"
	MinSupported string                  `json:"minSupported"` // en-deçà : mise à jour fortement recommandée
	Assets       map[string]ReleaseAsset `json:"assets"`       // clé = nom de fichier de l'asset
}

// ReleaseAsset est un binaire téléchargeable d'une release.
type ReleaseAsset struct {
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
	// Sig est la signature ed25519 (base64) du binaire, produite HORS LIGNE
	// par le mainteneur (cmd/relsign) et simplement relayée par le serveur.
	// Exigée par selfupdate : sans signature, pas de mise à jour.
	Sig string `json:"sig,omitempty"`
}

// ExportResult résume la réponse de POST /ingest/export.
type ExportResult struct {
	Processed int `json:"processed"`
}

// FloorSample est un relevé d'étage (C_Map) transmis au serveur : t = epoch s,
// m = uiMapID de l'étage, x/y = position normalisée [0,1] sur l'étage.
type FloorSample struct {
	T int64   `json:"t"`
	M int64   `json:"m"`
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

// CombatMeta décrit le run associé à un segment de log. Le sha256 et la taille
// brute sont calculés par l'uploader à partir du segment lui-même.
type CombatMeta struct {
	Realm        string
	Uploader     string // nom du personnage qui loggait
	InstanceName string
	MapID        int64
	StartedAt    int64
	EndedAt      int64
	// Floors : timeline d'étage captée par l'addon (peut être vide pour les
	// runs antérieurs à la maj addon, ou hors donjon vertical).
	Floors []FloorSample
}

// CombatResult résume la réponse de POST /ingest/combatlog.
type CombatResult struct {
	UploadID  int64  `json:"uploadId"`
	Duplicate bool   `json:"duplicate"`
	Status    string `json:"status"`
}

// HTTPError porte le code HTTP et l'enveloppe d'erreur serveur. Les 4xx de
// CONTENU (hors 429 et hors auth) sont définitifs : re-tenter à l'identique
// est inutile.
type HTTPError struct {
	StatusCode int
	Code       string
	Message    string
}

func (e *HTTPError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("upload: statut %d (%s): %s", e.StatusCode, e.Code, e.Message)
	}
	return fmt.Sprintf("upload: statut %d", e.StatusCode)
}

// Definitive indique une erreur qu'il ne faut pas retenter telle quelle : le
// CONTENU est refusé (format, signature…), le renvoyer à l'identique ne
// changera rien. Les erreurs d'AUTHENTIFICATION (401/403) n'en font PAS
// partie : une clé révoquée se reconnecte — marquer le contenu « transmis »
// sur un 401 le perdrait définitivement (vécu 2026-06-10 : runs de donjon
// grillés dans SentRuns pendant que la clé était morte, jamais re-tentés
// après le reconnect). Elles sont transitoires : on réessaiera.
func (e *HTTPError) Definitive() bool {
	return e.StatusCode >= 400 && e.StatusCode < 500 &&
		e.StatusCode != http.StatusTooManyRequests &&
		e.StatusCode != http.StatusUnauthorized &&
		e.StatusCode != http.StatusForbidden
}

// IsDefinitive teste si err est une erreur HTTP définitive (4xx de contenu,
// hors 429 et hors 401/403).
func IsDefinitive(err error) bool {
	var he *HTTPError
	return errors.As(err, &he) && he.Definitive()
}

// HTTPClient est l'implémentation réseau.
type HTTPClient struct {
	BaseURL string
	// APIKey fournit la clé d'ingestion courante (peut changer à chaud).
	APIKey func() string
	hc     *http.Client
}

// NewHTTP construit un client HTTP vers baseURL. apiKeyFn est appelée à chaque
// requête pour récupérer la clé courante.
func NewHTTP(baseURL string, apiKeyFn func() string) *HTTPClient {
	return &HTTPClient{
		BaseURL: baseURL,
		APIKey:  apiKeyFn,
		hc:      &http.Client{Timeout: 60 * time.Second},
	}
}

// Status réalise le handshake /ingest/status.
func (c *HTTPClient) Status(ctx context.Context) (StatusResponse, error) {
	var out StatusResponse
	body, err := c.do(ctx, http.MethodGet, "/ingest/status", nil)
	if err != nil {
		return out, err
	}
	if err := json.Unmarshal(body, &out); err != nil {
		return out, fmt.Errorf("upload: réponse status illisible: %w", err)
	}
	return out, nil
}

// SendExport poste l'export signé vers /ingest/export.
func (c *HTTPClient) SendExport(ctx context.Context, jsonData string) (ExportResult, error) {
	var out ExportResult
	payload, err := json.Marshal(map[string]string{"jsonData": jsonData})
	if err != nil {
		return out, err
	}
	body, err := c.do(ctx, http.MethodPost, "/ingest/export", payload)
	if err != nil {
		return out, err
	}
	_ = json.Unmarshal(body, &out)
	return out, nil
}

// SendDungeonLog gzippe + encode le segment et le poste vers /ingest/combatlog.
func (c *HTTPClient) SendDungeonLog(ctx context.Context, meta CombatMeta, raw []byte) (CombatResult, error) {
	var out CombatResult

	sum := sha256.Sum256(raw)
	var gz bytes.Buffer
	w := gzip.NewWriter(&gz)
	if _, err := w.Write(raw); err != nil {
		return out, err
	}
	if err := w.Close(); err != nil {
		return out, err
	}

	metaMap := map[string]any{
		"sha256":        hex.EncodeToString(sum[:]),
		"sizeRaw":       len(raw),
		"client":        clientName,
		"clientVersion": ClientVersion,
		"realm":         meta.Realm,
		"uploader":      meta.Uploader,
		"instance":      map[string]any{"name": meta.InstanceName, "mapId": meta.MapID},
		"startedAt":     meta.StartedAt,
		"endedAt":       meta.EndedAt,
		"logFormat":     "wow-combatlog-1.15",
	}
	if len(meta.Floors) > 0 {
		metaMap["floors"] = meta.Floors
	}
	body := map[string]any{
		"meta":          metaMap,
		"logGzipBase64": base64.StdEncoding.EncodeToString(gz.Bytes()),
	}
	payload, err := json.Marshal(body)
	if err != nil {
		return out, err
	}
	respBody, err := c.do(ctx, http.MethodPost, "/ingest/combatlog", payload)
	if err != nil {
		return out, err
	}
	_ = json.Unmarshal(respBody, &out)
	return out, nil
}

// do exécute une requête avec retry à backoff exponentiel sur les erreurs
// transitoires (réseau, 429, 5xx). Les 4xx (hors 429) sont renvoyés comme
// *HTTPError définitif sans retry. body nil => requête sans corps (GET).
func (c *HTTPClient) do(ctx context.Context, method, path string, body []byte) ([]byte, error) {
	if c.BaseURL == "" {
		return nil, fmt.Errorf("upload: endpoint non configuré")
	}
	key := ""
	if c.APIKey != nil {
		key = c.APIKey()
	}
	if key == "" {
		return nil, fmt.Errorf("upload: clé API non configurée")
	}

	var lastErr error
	backoff := time.Second
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(backoff):
			}
			backoff *= 2
		}

		var reqBody io.Reader
		if body != nil {
			reqBody = bytes.NewReader(body)
		}
		req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, reqBody)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Authorization", "Bearer "+key)
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}

		resp, err := c.hc.Do(req)
		if err != nil {
			lastErr = err
			continue // erreur réseau : transitoire
		}
		data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		resp.Body.Close()

		switch {
		case resp.StatusCode >= 200 && resp.StatusCode < 300:
			return data, nil
		case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
			lastErr = &HTTPError{StatusCode: resp.StatusCode}
			continue // transitoire : on retente
		default:
			// 4xx définitif : inutile de retenter.
			return nil, parseHTTPError(resp.StatusCode, data)
		}
	}
	return nil, fmt.Errorf("upload: échec après plusieurs tentatives: %w", lastErr)
}

// parseHTTPError décode l'enveloppe d'erreur { error, message } si présente.
func parseHTTPError(status int, body []byte) *HTTPError {
	e := &HTTPError{StatusCode: status}
	var env struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	if json.Unmarshal(body, &env) == nil {
		e.Code = env.Error
		e.Message = env.Message
	}
	return e
}
