package version

import "testing"

func TestCompare(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		{"v0.1.7", "v0.1.7", 0},
		{"0.1.7", "v0.1.7", 0},
		{"v0.1.7", "v0.1.8", -1},
		{"v0.2.0", "v0.1.9", 1},
		{"v1.0.0", "v0.9.9", 1},
		{"v0.1", "v0.1.0", 0},
		{"v0.2.0-rc1", "v0.2.0", 0},
		{"dev", "v0.1.0", -1},
		{"v0.1.0", "dev", 1},
		{"dev", "", 0},
	}
	for _, c := range cases {
		if got := Compare(c.a, c.b); got != c.want {
			t.Errorf("Compare(%q, %q) = %d, attendu %d", c.a, c.b, got, c.want)
		}
	}
}
