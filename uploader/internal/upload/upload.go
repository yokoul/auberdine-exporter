// Package upload transmet les données à auberdine.eu.
//
// Le transport réel est masqué derrière l'interface Uploader afin que le reste
// du démon ne dépende pas du contrat HTTP précis (encore à figer côté serveur).
// L'implémentation HTTP applique gzip, l'authentification Discord et un retry à
// backoff exponentiel.
package upload

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Uploader transmet exports et segments de log de donjon.
type Uploader interface {
	// SendExport transmet la structure de données de l'addon (JSON déjà sérialisé).
	SendExport(ctx context.Context, accountKey string, payload []byte) error
	// SendDungeonLog transmet un segment brut de log de combat pour un run.
	SendDungeonLog(ctx context.Context, meta DungeonMeta, raw []byte) error
}

// DungeonMeta décrit le run associé à un segment de log transmis brut.
type DungeonMeta struct {
	RunID     string `json:"runId"`
	Instance  string `json:"instance"`
	Character string `json:"character"`
	StartedAt int64  `json:"startedAt"`
	EndedAt   int64  `json:"endedAt"`
}

// HTTPClient est l'implémentation réseau.
type HTTPClient struct {
	BaseURL string
	// Token est le jeton d'accès Discord (Bearer).
	Token func() string
	hc    *http.Client
}

// NewHTTP construit un client HTTP vers baseURL. tokenFn est appelée à chaque
// requête pour récupérer le jeton courant (il peut être rafraîchi entre-temps).
func NewHTTP(baseURL string, tokenFn func() string) *HTTPClient {
	return &HTTPClient{
		BaseURL: baseURL,
		Token:   tokenFn,
		hc:      &http.Client{Timeout: 60 * time.Second},
	}
}

// SendExport poste le JSON de l'addon vers /ingest/export.
func (c *HTTPClient) SendExport(ctx context.Context, accountKey string, payload []byte) error {
	return c.post(ctx, "/ingest/export", map[string]string{
		"X-Auberdine-Account": accountKey,
	}, payload)
}

// SendDungeonLog poste un segment brut vers /ingest/combatlog.
func (c *HTTPClient) SendDungeonLog(ctx context.Context, meta DungeonMeta, raw []byte) error {
	return c.post(ctx, "/ingest/combatlog", map[string]string{
		"X-Auberdine-Run":       meta.RunID,
		"X-Auberdine-Instance":  meta.Instance,
		"X-Auberdine-Character": meta.Character,
	}, raw)
}

// post envoie un corps gzippé avec retry à backoff exponentiel.
func (c *HTTPClient) post(ctx context.Context, path string, headers map[string]string, body []byte) error {
	if c.BaseURL == "" {
		return fmt.Errorf("upload: endpoint non configuré")
	}

	var gz bytes.Buffer
	w := gzip.NewWriter(&gz)
	if _, err := w.Write(body); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	compressed := gz.Bytes()

	var lastErr error
	backoff := time.Second
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(backoff):
			}
			backoff *= 2
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+path, bytes.NewReader(compressed))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Content-Encoding", "gzip")
		if c.Token != nil {
			if tok := c.Token(); tok != "" {
				req.Header.Set("Authorization", "Bearer "+tok)
			}
		}
		for k, v := range headers {
			req.Header.Set(k, v)
		}

		resp, err := c.hc.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()

		switch {
		case resp.StatusCode >= 200 && resp.StatusCode < 300:
			return nil
		case resp.StatusCode == 429 || resp.StatusCode >= 500:
			// Erreur transitoire : on retente.
			lastErr = fmt.Errorf("upload: statut %d", resp.StatusCode)
			continue
		default:
			// Erreur définitive (4xx hors 429) : inutile de retenter.
			return fmt.Errorf("upload: statut %d (définitif)", resp.StatusCode)
		}
	}
	return fmt.Errorf("upload: échec après plusieurs tentatives: %w", lastErr)
}
