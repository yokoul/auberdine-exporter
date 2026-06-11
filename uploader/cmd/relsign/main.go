// relsign — signature ed25519 des releases de l'uploader.
//
// La clé PRIVÉE vit sur le poste du mainteneur (jamais versionnée, jamais
// sur le serveur) ; la clé PUBLIQUE est embarquée dans le binaire du client
// (internal/selfupdate). Le serveur d'ingestion ne fait que RELAYER les
// signatures publiées avec la release GitHub : sa compromission ne suffit
// plus à pousser du code aux clients (audit 2026-06, point 1).
//
//	go run ./cmd/relsign keygen -key <fichier>          # génère la paire, affiche la publique
//	go run ./cmd/relsign sign   -key <fichier> <bin>…   # écrit <bin>.sig (base64)
//	go run ./cmd/relsign verify -pub <base64> <bin>     # contrôle <bin>.sig
//
// Format du fichier de clé : une ligne base64 = seed ed25519 (32 octets), 0600.
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fatalf("usage: relsign keygen|sign|verify …")
	}
	switch os.Args[1] {
	case "keygen":
		cmdKeygen(os.Args[2:])
	case "sign":
		cmdSign(os.Args[2:])
	case "verify":
		cmdVerify(os.Args[2:])
	default:
		fatalf("sous-commande inconnue: %s", os.Args[1])
	}
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "relsign: "+format+"\n", args...)
	os.Exit(1)
}

func loadKey(path string) ed25519.PrivateKey {
	raw, err := os.ReadFile(path)
	if err != nil {
		fatalf("clé privée: %v", err)
	}
	seed, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(raw)))
	if err != nil || len(seed) != ed25519.SeedSize {
		fatalf("clé privée illisible (attendu base64 d'un seed de %d octets)", ed25519.SeedSize)
	}
	return ed25519.NewKeyFromSeed(seed)
}

func cmdKeygen(args []string) {
	fs := flag.NewFlagSet("keygen", flag.ExitOnError)
	keyPath := fs.String("key", "", "fichier de clé privée à créer")
	fs.Parse(args)
	if *keyPath == "" {
		fatalf("keygen: -key requis")
	}
	if _, err := os.Stat(*keyPath); err == nil {
		fatalf("keygen: %s existe déjà — refus d'écraser une clé de release", *keyPath)
	}
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		fatalf("keygen: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(*keyPath), 0o700); err != nil {
		fatalf("keygen: %v", err)
	}
	seed := base64.StdEncoding.EncodeToString(priv.Seed())
	if err := os.WriteFile(*keyPath, []byte(seed+"\n"), 0o600); err != nil {
		fatalf("keygen: %v", err)
	}
	fmt.Printf("clé privée : %s (0600 — à sauvegarder hors ligne, JAMAIS versionnée)\n", *keyPath)
	fmt.Printf("clé publique (à embarquer dans internal/selfupdate) :\n%s\n",
		base64.StdEncoding.EncodeToString(pub))
}

func cmdSign(args []string) {
	fs := flag.NewFlagSet("sign", flag.ExitOnError)
	keyPath := fs.String("key", "", "fichier de clé privée")
	fs.Parse(args)
	if *keyPath == "" || fs.NArg() == 0 {
		fatalf("sign: -key <fichier> puis au moins un binaire")
	}
	priv := loadKey(*keyPath)
	for _, target := range fs.Args() {
		data, err := os.ReadFile(target)
		if err != nil {
			fatalf("sign %s: %v", target, err)
		}
		sig := base64.StdEncoding.EncodeToString(ed25519.Sign(priv, data))
		if err := os.WriteFile(target+".sig", []byte(sig+"\n"), 0o644); err != nil {
			fatalf("sign %s: %v", target, err)
		}
		fmt.Printf("signé : %s.sig\n", target)
	}
}

func cmdVerify(args []string) {
	fs := flag.NewFlagSet("verify", flag.ExitOnError)
	pub64 := fs.String("pub", "", "clé publique base64")
	fs.Parse(args)
	if *pub64 == "" || fs.NArg() != 1 {
		fatalf("verify: -pub <base64> puis un binaire (le .sig est lu à côté)")
	}
	pub, err := base64.StdEncoding.DecodeString(*pub64)
	if err != nil || len(pub) != ed25519.PublicKeySize {
		fatalf("verify: clé publique invalide")
	}
	target := fs.Arg(0)
	data, err := os.ReadFile(target)
	if err != nil {
		fatalf("verify: %v", err)
	}
	rawSig, err := os.ReadFile(target + ".sig")
	if err != nil {
		fatalf("verify: %v", err)
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(rawSig)))
	if err != nil {
		fatalf("verify: signature illisible")
	}
	if !ed25519.Verify(ed25519.PublicKey(pub), data, sig) {
		fatalf("verify: SIGNATURE INVALIDE pour %s", target)
	}
	fmt.Printf("signature valide : %s\n", target)
}
