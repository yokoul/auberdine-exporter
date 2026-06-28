// Package atomicfile écrit un fichier de façon atomique : un fichier temporaire
// voisin est écrit, fsync-é, puis renommé sur la cible (rename atomique sur le
// même système de fichiers). Une interruption — coupure de courant, redémarrage
// brutal — ne peut donc jamais laisser la cible tronquée ou à moitié écrite :
// soit l'ancien contenu intact, soit le nouveau complet.
//
// Motivation : state.json et config.json étaient écrits par os.WriteFile
// (troncature-puis-écriture). Un arrêt brutal pendant une écriture corrompait
// le fichier, et le client refusait ensuite de démarrer (cf. incident legioul,
// Windows). L'écriture atomique supprime cette classe de panne.
package atomicfile

import (
	"os"
	"path/filepath"
)

// Write écrit data dans path de façon atomique avec les permissions perm.
// Le fichier temporaire est créé dans le même répertoire que path pour que le
// rename final reste sur le même volume (donc atomique). En cas d'échec avant
// le rename, path conserve son contenu précédent et le temporaire est nettoyé.
func Write(path string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	// Filet : si on sort en erreur avant le rename, le temporaire ne traîne pas.
	// Après un rename réussi, ce Remove échoue silencieusement (fichier déplacé).
	defer os.Remove(tmpName)

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(perm); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil { // flush sur disque avant le rename
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}
