# Auberdine Uploader — installation en une ligne (Windows) :
#
#   irm https://auberdine.eu/uploader/install.ps1 | iex
#
# Télécharge le binaire depuis les releases GitHub, connecte le compte
# (navigateur, session Discord d'auberdine.eu) puis pose le démarrage
# automatique (clé Run utilisateur, aucune élévation). Invoke-WebRequest
# ne pose pas le Mark-of-the-Web : aucune alerte SmartScreen à ignorer.
#
# Aucune élévation requise : tout vit dans le profil utilisateur (clé Run
# HKCU + %LOCALAPPDATA%). Inutile de lancer PowerShell en administrateur.
#
# Source : https://github.com/yokoul/auberdine-exporter (uploader/scripts/)
$ErrorActionPreference = 'Stop'

# Consoles héritées en page de code OEM : on bascule l'affichage en UTF-8
# pour que les messages accentués (script + binaire) restent lisibles.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$repo  = 'yokoul/auberdine-exporter'
$asset = 'auberdine-uploader-windows-amd64.exe'
$url   = "https://github.com/$repo/releases/latest/download/$asset"
# Surtout PAS de « install » ou « setup » dans le nom du fichier : l'Installer
# Detection de l'UAC exigerait l'élévation pour un exe sans manifest portant
# un tel nom (« L'opération demandée nécessite une élévation », vécu).
$tmp   = Join-Path $env:TEMP 'auberdine-uploader.exe'

Write-Host "-> Téléchargement de $asset..."
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp

# Lance un binaire GUI et n'attend QUE lui. Surtout pas Start-Process -Wait :
# sous Windows PowerShell 5.1 il attend aussi les DESCENDANTS — install
# démarre le service en arrière-plan, le script ne rendait jamais la main.
function Invoke-Uploader([string]$Arguments) {
    $p = Start-Process -FilePath $tmp -ArgumentList $Arguments -NoNewWindow -PassThru
    $p.WaitForExit()
}

# Connexion AVANT l'installation : le service démarre déjà connecté.
$cfgPath = Join-Path $env:APPDATA 'auberdine-uploader\config.json'
$hasKey = $false
if (Test-Path $cfgPath) {
    try { $hasKey = [bool](Get-Content $cfgPath -Raw | ConvertFrom-Json).apiKey } catch {}
}
if ($hasKey) {
    Write-Host '-> Clé d''ingestion déjà configurée — connexion conservée.'
} else {
    Write-Host '-> Connexion à auberdine.eu (le navigateur va s''ouvrir)...'
    Invoke-Uploader 'connect'
}

Write-Host '-> Installation du démarrage automatique...'
Invoke-Uploader 'install'

Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host ''
Write-Host 'Auberdine Uploader est installé : vos exports partiront tout seuls'
Write-Host 'à la prochaine déconnexion en jeu. L''icône vit dans la zone de notification.'
Write-Host 'Vous pouvez fermer cette fenêtre — l''uploader continue en arrière-plan.'
