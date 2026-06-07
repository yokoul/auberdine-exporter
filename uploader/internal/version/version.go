// Package version porte la version du binaire, injectée au build :
//
//	go build -ldflags "-X github.com/yokoul/auberdine-exporter/uploader/internal/version.Version=v0.2.0"
//
// Sans injection (go run, build local), la version vaut "dev" — la mise à
// jour automatique est alors désactivée (un build de dev ne s'écrase pas).
package version

import (
	"strconv"
	"strings"
)

// Version est la version du binaire (tag de release, ex. "v0.2.0").
var Version = "dev"

// IsDev indique un build local sans version injectée.
func IsDev() bool { return Version == "dev" }

// Compare compare deux versions "vX.Y.Z" (préfixe v optionnel, composantes
// manquantes = 0). Renvoie -1, 0 ou 1. Toute version non numérique (dev,
// vide) est considérée plus ancienne que n'importe quelle version valide.
func Compare(a, b string) int {
	pa, okA := parse(a)
	pb, okB := parse(b)
	if !okA && !okB {
		return 0
	}
	if !okA {
		return -1
	}
	if !okB {
		return 1
	}
	for i := 0; i < 3; i++ {
		if pa[i] != pb[i] {
			if pa[i] < pb[i] {
				return -1
			}
			return 1
		}
	}
	return 0
}

func parse(v string) ([3]int, bool) {
	var out [3]int
	v = strings.TrimPrefix(strings.TrimSpace(v), "v")
	if v == "" {
		return out, false
	}
	// Ignore un éventuel suffixe de pré-release ("0.2.0-rc1" → "0.2.0").
	if i := strings.IndexAny(v, "-+"); i >= 0 {
		v = v[:i]
	}
	parts := strings.Split(v, ".")
	if len(parts) > 3 {
		return out, false
	}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil || n < 0 {
			return out, false
		}
		out[i] = n
	}
	return out, true
}
