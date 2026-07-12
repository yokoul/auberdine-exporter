//go:build windows

package discovery

import "testing"

func TestProductDBRootsFrom(t *testing.T) {
	// Extrait synthétique : product.db est du protobuf binaire, les chemins y
	// figurent en clair en forward slashes, entourés d'octets de framing.
	data := []byte("\x0a\x2fC:/Program Files (x86)/World of Warcraft\x12\x04fr" +
		"\x00\x0a\x1dD:/Jeux/World of Warcraft\x12\x03wow" +
		"\x0a\x08no match")
	got := productDBRootsFrom(data)
	want := []string{
		`C:\Program Files (x86)\World of Warcraft`,
		`D:\Jeux\World of Warcraft`,
	}
	if len(got) != len(want) {
		t.Fatalf("attendu %v, obtenu %v", want, got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("chemin %d : attendu %q, obtenu %q", i, want[i], got[i])
		}
	}
}

func TestNormalizeRoot(t *testing.T) {
	cases := []struct{ in, want string }{
		{`D:\Jeux\World of Warcraft\_retail_`, `D:\Jeux\World of Warcraft`},
		{`D:\Jeux\World of Warcraft\_classic_era_`, `D:\Jeux\World of Warcraft`},
		{`D:\Jeux\World of Warcraft`, `D:\Jeux\World of Warcraft`},
		{`D:\Jeux\World of Warcraft\`, `D:\Jeux\World of Warcraft`},
	}
	for _, c := range cases {
		if got := normalizeRoot(c.in); got != c.want {
			t.Errorf("normalizeRoot(%q) = %q, attendu %q", c.in, got, c.want)
		}
	}
}
