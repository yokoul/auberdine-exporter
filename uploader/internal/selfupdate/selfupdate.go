// Package selfupdate met à jour le binaire en place, piloté par le serveur :
// la réponse de /ingest/status annonce la dernière release (tag + URL + sha256
// par plateforme), le démon télécharge, vérifie l'empreinte, remplace son
// propre exécutable puis redémarre.
//
// Garde-fous :
//   - un build "dev" (version non injectée) ne se met jamais à jour ;
//   - pas de sha256 annoncé, ou URL non-HTTPS => pas de mise à jour ;
//   - l'empreinte est vérifiée AVANT toute substitution : un téléchargement
//     corrompu ou falsifié ne touche pas au binaire en place ;
//   - en cas d'échec, le binaire courant reste intact et le service continue.
//
// Le remplacement suit le rename-trick portable : écrire le nouveau binaire à
// côté (.new), écarter l'ancien (.old — Windows interdit d'écraser un exe en
// cours d'exécution mais autorise son renommage), glisser le nouveau à sa
// place. Le reste (.old orphelin) est nettoyé au démarrage suivant.
package selfupdate

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/yokoul/auberdine-exporter/uploader/internal/upload"
	"github.com/yokoul/auberdine-exporter/uploader/internal/version"
)

// maxBinarySize borne le téléchargement (un binaire Go + systray pèse
// quelques Mo ; 100 Mo = garde-fou contre une réponse aberrante).
const maxBinarySize = 100 << 20

// AssetName renvoie le nom de l'asset de release pour la plateforme courante
// (ex. "auberdine-uploader-windows-amd64.exe").
func AssetName() string {
	name := fmt.Sprintf("auberdine-uploader-%s-%s", runtime.GOOS, runtime.GOARCH)
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	return name
}

// Available indique si rel annonce une version plus récente que le binaire
// courant, avec un asset utilisable pour cette plateforme. Un build dev ne se
// met jamais à jour.
func Available(rel *upload.ClientRelease) (upload.ReleaseAsset, bool) {
	if rel == nil || version.IsDev() {
		return upload.ReleaseAsset{}, false
	}
	if version.Compare(version.Version, rel.Latest) >= 0 {
		return upload.ReleaseAsset{}, false
	}
	asset, ok := rel.Assets[AssetName()]
	if !ok || asset.SHA256 == "" || !strings.HasPrefix(asset.URL, "https://") {
		return upload.ReleaseAsset{}, false
	}
	return asset, true
}

// Apply télécharge l'asset, vérifie son empreinte et remplace l'exécutable
// courant. Renvoie le chemin du binaire substitué, à passer à Restart : après
// le swap, os.Executable() n'est plus fiable (chemin renommé sous Windows,
// « (deleted) » sous Linux). Ne redémarre PAS : c'est à l'appelant d'invoquer
// Restart une fois prêt (uploads en cours terminés).
func Apply(ctx context.Context, asset upload.ReleaseAsset) (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("selfupdate: exécutable courant introuvable: %w", err)
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", err
	}
	return applyTo(ctx, asset, exe)
}

// applyTo réalise téléchargement, vérification et substitution sur un chemin
// cible explicite (séparé d'Apply pour les tests).
func applyTo(ctx context.Context, asset upload.ReleaseAsset, exe string) (string, error) {
	tmp := exe + ".new"
	if err := download(ctx, asset, tmp); err != nil {
		os.Remove(tmp)
		return "", err
	}

	// Écarte l'ancien binaire puis glisse le nouveau à sa place. Sous Unix le
	// rename direct suffirait, mais passer par .old garde un chemin de
	// restauration identique sur les trois plateformes.
	old := exe + ".old"
	os.Remove(old) // reliquat d'une mise à jour précédente
	if err := os.Rename(exe, old); err != nil {
		os.Remove(tmp)
		return "", fmt.Errorf("selfupdate: écarter l'ancien binaire: %w", err)
	}
	if err := os.Rename(tmp, exe); err != nil {
		// Restauration : l'ancien binaire reprend sa place.
		if rerr := os.Rename(old, exe); rerr != nil {
			return "", fmt.Errorf("selfupdate: substitution ET restauration échouées (%v puis %v) — réinstallez via https://auberdine.eu/uploader/", err, rerr)
		}
		os.Remove(tmp)
		return "", fmt.Errorf("selfupdate: substitution: %w", err)
	}
	// Sous Unix la suppression immédiate passe (l'inode survit au process en
	// cours) ; sous Windows l'exe en cours est verrouillé, le .old sera
	// nettoyé par CleanupLeftovers au prochain démarrage.
	os.Remove(old)
	return exe, nil
}

// download écrit l'asset vérifié dans dest (0755). L'empreinte est contrôlée
// sur le fichier complet avant de renvoyer nil.
func download(ctx context.Context, asset upload.ReleaseAsset, dest string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, asset.URL, nil)
	if err != nil {
		return err
	}
	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("selfupdate: téléchargement: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("selfupdate: téléchargement: statut %d", resp.StatusCode)
	}

	out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(out, h), io.LimitReader(resp.Body, maxBinarySize+1))
	if cerr := out.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return fmt.Errorf("selfupdate: écriture: %w", err)
	}
	if n > maxBinarySize {
		return fmt.Errorf("selfupdate: binaire anormalement gros (> %d Mo)", maxBinarySize>>20)
	}
	got := hex.EncodeToString(h.Sum(nil))
	want := strings.ToLower(strings.TrimSpace(asset.SHA256))
	if got != want {
		return fmt.Errorf("selfupdate: empreinte sha256 invalide (obtenu %s, annoncé %s)", got, want)
	}
	return nil
}

// CleanupLeftovers retire les restes d'une mise à jour précédente (.old, .new)
// à côté de l'exécutable courant. Best-effort : sous Windows un .old encore
// verrouillé par une instance mourante sera repris au prochain démarrage.
func CleanupLeftovers() {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	if exe, err = filepath.EvalSymlinks(exe); err != nil {
		return
	}
	os.Remove(exe + ".old")
	os.Remove(exe + ".new")
}
