package discovery

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNormalizeVersionDir(t *testing.T) {
	root := t.TempDir()
	wow := filepath.Join(root, "World of Warcraft")
	era := filepath.Join(wow, versionDirName)
	if err := os.MkdirAll(era, 0o755); err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		name   string
		picked string
		want   string
		ok     bool
	}{
		{"dossier de version lui-même", era, era, true},
		{"racine World of Warcraft", wow, era, true},
		{"parent direct (ex. D:\\Jeux)", root, era, true},
		{"dossier sans rapport", t.TempDir(), "", false},
		{"chemin inexistant", filepath.Join(root, "nope"), "", false},
	}
	for _, c := range cases {
		got, ok := NormalizeVersionDir(c.picked)
		if ok != c.ok || got != c.want {
			t.Errorf("%s: NormalizeVersionDir(%q) = (%q, %v), attendu (%q, %v)",
				c.name, c.picked, got, ok, c.want, c.ok)
		}
	}
}

func TestVersionDirsFromRootsDedup(t *testing.T) {
	got := versionDirsFromRoots([]string{
		filepath.Join("a", "World of Warcraft"),
		filepath.Join("a", "World of Warcraft"), // doublon exact
		filepath.Join("b", "World of Warcraft"),
	})
	if len(got) != 2 {
		t.Fatalf("attendu 2 candidats dédupliqués, obtenu %d : %v", len(got), got)
	}
}
