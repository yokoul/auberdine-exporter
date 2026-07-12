//go:build windows

package main

import (
	"log"
	"os/exec"
	"strings"
	"syscall"
	"unsafe"

	"github.com/yokoul/auberdine-exporter/uploader/internal/config"
	"github.com/yokoul/auberdine-exporter/uploader/internal/discovery"
)

// promptWoWPath s'affiche quand l'auto-détection échoue : le binaire tourne en
// -H windowsgui, sans lui l'échec serait invisible (crash-loop muet dans le
// log, vécu — installation WoW sur un disque non standard). Il guide
// l'utilisateur vers son dossier World of Warcraft via un dialogue natif,
// persiste wowPath et rend true si la config est désormais exploitable.
func promptWoWPath(cfg *config.Config, logger *log.Logger) bool {
	intro := "L'uploader n'a pas trouvé votre installation de World of Warcraft Classic Era.\n\n" +
		"Cliquez sur OK pour désigner le dossier « World of Warcraft »\n" +
		"(celui qui contient le sous-dossier _classic_era_)."
	if !messageBoxOKCancel("Auberdine Uploader — WoW introuvable", intro) {
		logger.Print("configuration wowPath refusée par l'utilisateur")
		return false
	}
	for {
		picked := pickFolder()
		if picked == "" {
			logger.Print("sélection du dossier WoW annulée")
			return false
		}
		versionDir, ok := discovery.NormalizeVersionDir(picked)
		if !ok {
			retry := "Le dossier sélectionné ne contient pas _classic_era_ :\n\n" + picked +
				"\n\nRéessayer avec un autre dossier ?"
			if !messageBoxOKCancel("Auberdine Uploader — dossier invalide", retry) {
				return false
			}
			continue
		}
		cfg.WoWPath = versionDir
		if err := cfg.Save(); err != nil {
			logger.Printf("enregistrement de wowPath: %v", err)
			return false
		}
		logger.Printf("wowPath configuré par l'utilisateur : %s", versionDir)
		return true
	}
}

// pickFolder ouvre le sélecteur de dossier Windows (FolderBrowserDialog via
// PowerShell, fenêtre console masquée — le dialogue GUI, lui, s'affiche).
// Renvoie "" si l'utilisateur annule ou en cas d'échec.
func pickFolder() string {
	script := `Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$d = New-Object System.Windows.Forms.FolderBrowserDialog
$d.Description = 'Sélectionnez le dossier World of Warcraft (contenant _classic_era_)'
$d.ShowNewFolderButton = $false
$owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
if ($d.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write($d.SelectedPath)
}`
	const createNoWindow = 0x08000000
	cmd := exec.Command("powershell", "-NoProfile", "-STA", "-Command", script)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// messageBoxOKCancel affiche une MessageBox native OK/Annuler au premier plan
// et rend true si l'utilisateur valide.
func messageBoxOKCancel(caption, text string) bool {
	const (
		mbOKCancel      = 0x00000001
		mbIconWarning   = 0x00000030
		mbSetForeground = 0x00010000
		idOK            = 1
	)
	user32 := syscall.NewLazyDLL("user32.dll")
	proc := user32.NewProc("MessageBoxW")
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString(caption)
	ret, _, _ := proc.Call(0,
		uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)),
		uintptr(mbOKCancel|mbIconWarning|mbSetForeground))
	return ret == idOK
}
