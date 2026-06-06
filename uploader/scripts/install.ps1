# Auberdine Uploader — installation en une ligne (Windows) :
#
#   irm https://auberdine.eu/uploader/install.ps1 | iex
#
# Télécharge le binaire depuis les releases GitHub, connecte le compte
# (navigateur, session Discord d'auberdine.eu) puis pose le démarrage
# automatique (clé Run utilisateur, aucune élévation). Invoke-WebRequest
# ne pose pas le Mark-of-the-Web : aucune alerte SmartScreen à ignorer.
#
# Source : https://github.com/yokoul/auberdine-exporter (uploader/scripts/)
$ErrorActionPreference = 'Stop'

$repo  = 'yokoul/auberdine-exporter'
$asset = 'auberdine-uploader-windows-amd64.exe'
$url   = "https://github.com/$repo/releases/latest/download/$asset"
$tmp   = Join-Path $env:TEMP 'auberdine-uploader-install.exe'

Write-Host "-> Téléchargement de $asset..."
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp

# Connexion AVANT l'installation : le service démarre déjà connecté.
# (Binaire GUI : Start-Process -Wait, sinon PowerShell n'attend pas.)
$cfgPath = Join-Path $env:APPDATA 'auberdine-uploader\config.json'
$hasKey = $false
if (Test-Path $cfgPath) {
    try { $hasKey = [bool](Get-Content $cfgPath -Raw | ConvertFrom-Json).apiKey } catch {}
}
if ($hasKey) {
    Write-Host '-> Clé d''ingestion déjà configurée — connexion conservée.'
} else {
    Write-Host '-> Connexion à auberdine.eu (le navigateur va s''ouvrir)...'
    Start-Process -FilePath $tmp -ArgumentList 'connect' -Wait -NoNewWindow
}

Write-Host '-> Installation du démarrage automatique...'
Start-Process -FilePath $tmp -ArgumentList 'install' -Wait -NoNewWindow

Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host ''
Write-Host 'Auberdine Uploader est installé : vos exports partiront tout seuls'
Write-Host 'à la prochaine déconnexion en jeu. L''icône vit dans la zone de notification.'
