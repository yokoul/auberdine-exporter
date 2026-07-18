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
	"runtime"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/version"
)

// ClientVersion identifie le client dans les métadonnées d'upload (version
// réelle du binaire, injectée au build — "dev" sur un build local).
var ClientVersion = version.Version

const clientName = "auberdine-uploader"

// userAgent annonce le client à chaque requête /ingest : version réelle du
// binaire + OS + architecture. Le serveur le persiste par machine (clé
// d'ingestion) pour afficher « v0.2.0 · Windows » et un badge « à jour / MAJ
// dispo » dans le panneau Machines connectées du Camp. Forme :
//
//	auberdine-uploader/v0.2.0 (windows; amd64)
var userAgent = fmt.Sprintf("%s/%s (%s; %s)", clientName, version.Version, runtime.GOOS, runtime.GOARCH)

// Uploader transmet exports et segments de log de donjon.
type Uploader interface {
	// Status réalise le handshake /ingest/status (valide la clé, expose le lien Discord).
	Status(ctx context.Context) (StatusResponse, error)
	// SendExport transmet l'export signé de l'addon (chaîne JSON produite par l'addon).
	SendExport(ctx context.Context, jsonData string) (ExportResult, error)
	// SendDungeonLog transmet un segment de log de combat pour un run de donjon.
	SendDungeonLog(ctx context.Context, meta CombatMeta, raw []byte) (CombatResult, error)
	// Messages récupère les messages descendants en attente pour le compte
	// (canal site → uploader → addon → pop-up in-game).
	Messages(ctx context.Context) ([]InboxMessage, error)
	// AckMessages signale au serveur les messages déjà vus en jeu (lus de
	// AuberdineExporterDB.seenMessages). Idempotent.
	AckMessages(ctx context.Context, ids []string) error
	// Worldbuffs récupère l'agenda des world buffs planifiés (flux descendant
	// de données : site → uploader → SavedVariable → tooltip in-game).
	Worldbuffs(ctx context.Context) (WorldbuffsFeed, error)
	// SendWorldbuffSightings transmet les poses de world buffs observées en
	// jeu (voie montante : addon → uploader → site). Renvoie le nombre de
	// poses retenues côté serveur (hors doublons).
	SendWorldbuffSightings(ctx context.Context, sightings []WorldbuffSighting) (int, error)
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

// CombatMeta décrit le run associé à un segment de log. Le sha256 et la taille
// brute sont calculés par l'uploader à partir du segment lui-même.
type CombatMeta struct {
	Realm        string
	Uploader     string // nom du personnage qui loggait
	InstanceName string
	MapID        int64
	StartedAt    int64
	EndedAt      int64
}

// CombatResult résume la réponse de POST /ingest/combatlog.
type CombatResult struct {
	UploadID  int64  `json:"uploadId"`
	Duplicate bool   `json:"duplicate"`
	Status    string `json:"status"`
}

// InboxMessage est un message descendant destiné à l'affichage in-game. Mêmes
// champs que le contrat de la SavedVariable AuberdineUploaderInbox (Inbox.lua).
// Dates en epoch s ; ExpiresAt nullable.
type InboxMessage struct {
	ID        string `json:"id"`
	Kind      string `json:"kind"`
	Title     string `json:"title"`
	Body      string `json:"body"`
	CreatedAt *int64 `json:"createdAt"`
	ExpiresAt *int64 `json:"expiresAt"`
}

type messagesResponse struct {
	Success  bool           `json:"success"`
	Messages []InboxMessage `json:"messages"`
}

// WorldbuffEntry est une pose de world buff planifiée. Mêmes champs que le
// contrat de la SavedVariable AuberdineWorldbuffsFeed (Worldbuffs.lua).
type WorldbuffEntry struct {
	Buff    string `json:"buff"`
	At      int64  `json:"at"` // epoch s (UTC)
	Guild   string `json:"guild"`
	Faction string `json:"faction"` // "HORDE" | "ALLIANCE" | ""
}

// WorldbuffsFeed est l'agenda renvoyé par GET /ingest/feed/worldbuffs.
type WorldbuffsFeed struct {
	GeneratedAt int64
	Entries     []WorldbuffEntry
}

type worldbuffsResponse struct {
	Success     bool             `json:"success"`
	GeneratedAt int64            `json:"generatedAt"`
	Worldbuffs  []WorldbuffEntry `json:"worldbuffs"`
}

// WorldbuffSighting est une pose de world buff observée en jeu, telle
// qu'enregistrée par l'addon dans AuberdineExporterDB.wbSightings
// (WorldbuffLogger.lua).
type WorldbuffSighting struct {
	SpellID   int64  `json:"spellId"`
	Name      string `json:"name"`
	At        int64  `json:"at"` // epoch s (GetServerTime côté addon)
	Character string `json:"character"`
	Realm     string `json:"realm"`
	Guild     string `json:"guild"`
	Faction   string `json:"faction"` // "HORDE" | "ALLIANCE" | ""
	Zone      string `json:"zone"`
}

type sightingsResponse struct {
	Success bool `json:"success"`
	Stored  int  `json:"stored"`
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

// Messages récupère les messages descendants en attente (GET /ingest/messages).
func (c *HTTPClient) Messages(ctx context.Context) ([]InboxMessage, error) {
	body, err := c.do(ctx, http.MethodGet, "/ingest/messages", nil)
	if err != nil {
		return nil, err
	}
	var out messagesResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, fmt.Errorf("upload: réponse messages illisible: %w", err)
	}
	return out.Messages, nil
}

// AckMessages signale les messages vus (POST /ingest/messages/ack). No-op si
// la liste est vide.
func (c *HTTPClient) AckMessages(ctx context.Context, ids []string) error {
	if len(ids) == 0 {
		return nil
	}
	payload, err := json.Marshal(map[string][]string{"ids": ids})
	if err != nil {
		return err
	}
	_, err = c.do(ctx, http.MethodPost, "/ingest/messages/ack", payload)
	return err
}

// Worldbuffs récupère l'agenda des world buffs (GET /ingest/feed/worldbuffs).
func (c *HTTPClient) Worldbuffs(ctx context.Context) (WorldbuffsFeed, error) {
	body, err := c.do(ctx, http.MethodGet, "/ingest/feed/worldbuffs", nil)
	if err != nil {
		return WorldbuffsFeed{}, err
	}
	var out worldbuffsResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return WorldbuffsFeed{}, fmt.Errorf("upload: réponse worldbuffs illisible: %w", err)
	}
	return WorldbuffsFeed{GeneratedAt: out.GeneratedAt, Entries: out.Worldbuffs}, nil
}

// SendWorldbuffSightings poste les poses observées (POST
// /ingest/worldbuffs/sightings). No-op si la liste est vide.
func (c *HTTPClient) SendWorldbuffSightings(ctx context.Context, sightings []WorldbuffSighting) (int, error) {
	if len(sightings) == 0 {
		return 0, nil
	}
	payload, err := json.Marshal(map[string][]WorldbuffSighting{"sightings": sightings})
	if err != nil {
		return 0, err
	}
	body, err := c.do(ctx, http.MethodPost, "/ingest/worldbuffs/sightings", payload)
	if err != nil {
		return 0, err
	}
	var out sightingsResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return 0, fmt.Errorf("upload: réponse sightings illisible: %w", err)
	}
	return out.Stored, nil
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

	body := map[string]any{
		"meta": map[string]any{
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
		},
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
		req.Header.Set("User-Agent", userAgent)
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
