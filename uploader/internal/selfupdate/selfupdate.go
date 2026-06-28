// Package selfupdate met à jour le binaire en place, piloté par le serveur :
// la réponse de /ingest/status annonce la dernière release (tag + URL + sha256
// + signature par plateforme), le démon télécharge, vérifie l'empreinte ET la
// signature, remplace son propre exécutable puis redémarre.
//
// Garde-fous :
//   - un build "dev" (version non injectée) ne se met jamais à jour ;
//   - pas de sha256, pas de signature, ou URL non-HTTPS => pas de mise à jour ;
//   - l'empreinte ET la signature ed25519 sont vérifiées AVANT toute
//     substitution : un téléchargement corrompu ou falsifié ne touche pas au
//     binaire en place ;
//   - en cas d'échec, le binaire courant reste intact et le service continue.
//
// Signature des releases (audit 2026-06, point 1) : le sha256 annoncé par le
// serveur ne protège que du transit — URL et empreinte viennent de la même
// réponse, un serveur compromis pourrait donc pousser n'importe quel binaire.
// Chaque release est désormais signée HORS LIGNE (cmd/relsign, clé privée du
// mainteneur jamais présente sur le serveur) ; la clé publique ci-dessous est
// gravée dans le binaire et la signature est exigée avant le swap. Le serveur
// ne fait que relayer le .sig publié avec la release GitHub.
//
// Le remplacement suit le rename-trick portable : écrire le nouveau binaire à
// côté (.new), écarter l'ancien (.old — Windows interdit d'écraser un exe en
// cours d'exécution mais autorise son renommage), glisser le nouveau à sa
// place. Le reste (.old orphelin) est nettoyé au démarrage suivant.
package selfupdate

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
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

// releasePubKeyB64 est la clé publique ed25519 de signature des releases
// (générée par cmd/relsign keygen — la privée vit hors ligne chez le
// mainteneur). Variable et non constante : les tests injectent la leur.
var releasePubKeyB64 = "gg7QOG3c3V1MqCyndeO8R9eKynn1eJxhZlhSRVQWvao="

func releasePubKey() (ed25519.PublicKey, error) {
	raw, err := base64.StdEncoding.DecodeString(releasePubKeyB64)
	if err != nil || len(raw) != ed25519.PublicKeySize {
		return nil, fmt.Errorf("selfupdate: clé publique de release invalide")
	}
	return ed25519.PublicKey(raw), nil
}

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
	if !ok || asset.SHA256 == "" || asset.Sig == "" || !strings.HasPrefix(asset.URL, "https://") {
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
	// Glisse le nouveau binaire à la place de l'ancien. Sous Windows, un
	// antivirus (scan-on-write) tient souvent un verrou BREF sur l'exécutable
	// fraîchement écrit : un rename immédiat échoue alors qu'il réussirait une
	// fraction de seconde plus tard → on retente. SURTOUT, en cas d'échec, on
	// garantit que le chemin stable n'est JAMAIS laissé vide (restauration du
	// .old, retentée elle aussi) : sinon la clé de démarrage Windows pointe
	// vers un binaire manquant et plus rien ne se lance (incident legioul).
	if err := renameRetry(tmp, exe); err != nil {
		if rerr := renameRetry(old, exe); rerr != nil {
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

// renameRetry renomme from→to avec quelques tentatives espacées. Sous Windows,
// un antivirus ou l'indexeur peut tenir un verrou transitoire sur un fichier
// fraîchement écrit, faisant échouer un rename immédiat qui passerait peu après.
// Crucial pour la restauration du .old : ne jamais abandonner sur un simple
// verrou passager qui laisserait le chemin du binaire vide.
func renameRetry(from, to string) error {
	var err error
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			time.Sleep(200 * time.Millisecond)
		}
		if err = os.Rename(from, to); err == nil {
			return nil
		}
	}
	return err
}

// download écrit l'asset vérifié dans dest (0755). L'empreinte sha256 ET la
// signature ed25519 sont contrôlées sur le fichier complet avant de renvoyer
// nil — toute défaillance laisse le binaire en place intact.
func download(ctx context.Context, asset upload.ReleaseAsset, dest string) error {
	// Défense en profondeur (audit 2026-06, point 3) : Available() exige déjà
	// https://, on le revérifie ici au cas où un futur appelant court-circuite
	// ce garde-fou. Seul le loopback (tests) échappe à l'exigence — un
	// listener local relève déjà du même utilisateur.
	if !downloadURLAllowed(asset.URL) {
		return fmt.Errorf("selfupdate: URL de téléchargement refusée (https requis): %s", asset.URL)
	}
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
	return verifySignature(dest, asset.Sig)
}

// downloadURLAllowed n'accepte que https:// — plus http:// vers le loopback,
// pour les tests (un listener local relève déjà du même utilisateur).
func downloadURLAllowed(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil {
		return false
	}
	if u.Scheme == "https" {
		return true
	}
	h := u.Hostname()
	return u.Scheme == "http" && (h == "127.0.0.1" || h == "::1" || h == "localhost")
}

// verifySignature contrôle la signature ed25519 (base64) du fichier
// téléchargé contre la clé publique de release embarquée. Exigée : pas de
// signature, pas de mise à jour.
func verifySignature(path, sigB64 string) error {
	pub, err := releasePubKey()
	if err != nil {
		return err
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(sigB64))
	if err != nil || len(sig) != ed25519.SignatureSize {
		return fmt.Errorf("selfupdate: signature de release illisible")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, data, sig) {
		return fmt.Errorf("selfupdate: SIGNATURE DE RELEASE INVALIDE — binaire refusé")
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
