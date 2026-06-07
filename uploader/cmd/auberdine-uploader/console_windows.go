//go:build windows

// Le binaire tray Windows est compilé avec -H windowsgui pour ne pas ouvrir
// de fenêtre console au démarrage de session. Revers : lancé depuis un
// terminal, un binaire GUI n'a pas de sortie standard — les sous-commandes
// (install, connect, status, doctor) seraient muettes. On ré-attache donc la
// console du process parent quand elle existe, et on rouvre stdout/stderr
// dessus (CONOUT$). Lancé par la clé Run (pas de parent console), l'attache
// échoue silencieusement et le tray reste sans console — le comportement
// voulu.
//
// AttachConsole est appelé via syscall direct (kernel32) plutôt que
// golang.org/x/sys : le démon par défaut reste stdlib only.
package main

import (
	"os"
	"syscall"
)

func init() {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	attachConsole := kernel32.NewProc("AttachConsole")
	const attachParentProcess = ^uintptr(0) // (DWORD)-1

	r, _, _ := attachConsole.Call(attachParentProcess)
	if r == 0 {
		return // pas de console parente : démarrage de session, tray silencieux
	}
	// Les consoles Windows héritées tournent en page de code OEM (850/437) :
	// nos messages UTF-8 y affichent des accents cassés. On bascule la
	// console en UTF-8 (65001) — mojibake observé au premier install réel.
	kernel32.NewProc("SetConsoleOutputCP").Call(65001)
	if f, err := os.OpenFile("CONOUT$", os.O_WRONLY, 0); err == nil {
		os.Stdout = f
		os.Stderr = f
	}
}
