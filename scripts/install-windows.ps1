param(
  [ValidateSet('ADAM', 'FRNKLY.ONE', 'OPNDRM-APP')]
  [Parameter(Mandatory = $true)]
  [string]$Lane
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$PrimeDownloadBase = 'https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev'
$PrimeConfig = Join-Path $env:USERPROFILE '.prime\agent'

function Write-Step([string]$Message) { Write-Host "`n==> $Message" }
function Stop-Install([string]$Message) { throw "Open Dream Prime stopped: $Message" }
function Install-Winget([string]$Id) {
  Write-Host "Installing $Id"
  winget install --exact --id $Id --silent --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) { Stop-Install "Could not install $Id." }
}
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machinePath;$userPath"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Stop-Install 'Windows App Installer is required before setup can continue.' }

Write-Step 'Installing Git Bash, Node, GitHub CLI, WezTerm, and Ollama'
Install-Winget 'Git.Git'
Install-Winget 'OpenJS.NodeJS.LTS'
Install-Winget 'GitHub.cli'
Install-Winget 'wez.wezterm'
Install-Winget 'Ollama.Ollama'
Refresh-Path

Write-Step 'Installing HERDR Windows preview'
Invoke-RestMethod 'https://herdr.dev/install.ps1' | Invoke-Expression
Refresh-Path
if (-not (Get-Command herdr -ErrorAction SilentlyContinue)) { Stop-Install 'HERDR preview did not become available on PATH.' }

Write-Step 'Installing Prime Agent and the Open Dream Prime skill pack'
$version = ((Invoke-RestMethod "$PrimeDownloadBase/stable") -replace '^v', '').Trim()
if (-not $version) { Stop-Install 'Could not resolve the Prime Agent release.' }
$downloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) "opndrm-prime-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $downloadRoot | Out-Null
try {
  $tarballName = "prime-agent-$version.tgz"
  $tarball = Join-Path $downloadRoot $tarballName
  $checksums = Join-Path $downloadRoot 'SHA256SUMS'
  Invoke-WebRequest "$PrimeDownloadBase/releases/v$version/SHA256SUMS" -OutFile $checksums
  Invoke-WebRequest "$PrimeDownloadBase/releases/v$version/$tarballName" -OutFile $tarball
  $checksumLine = Select-String -LiteralPath $checksums -Pattern "\s$([regex]::Escape($tarballName))$" | Select-Object -First 1
  if (-not $checksumLine) { Stop-Install 'Prime Agent checksum metadata was incomplete.' }
  $expected = $checksumLine.Line.Split()[0].ToLowerInvariant()
  if ((Get-Sha256 $tarball) -ne $expected) { Stop-Install 'Prime Agent checksum verification failed.' }
  npm.cmd install --global $tarball
  if ($LASTEXITCODE -ne 0) { Stop-Install 'Prime Agent installation failed.' }
} finally {
  Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Refresh-Path
if (-not (Get-Command prime-agent -ErrorAction SilentlyContinue)) { Stop-Install 'Prime Agent is not available on PATH. Restart PowerShell, then run setup again.' }
prime-agent package install git:github.com/opndrm/prime
if ($LASTEXITCODE -ne 0) { Stop-Install 'The Open Dream Prime skill pack did not install.' }

Write-Step 'Installing No Mistakes and Buzz'
Invoke-RestMethod 'https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.ps1' | Invoke-Expression
$release = Invoke-RestMethod 'https://api.github.com/repos/block/buzz/releases/latest'
$asset = $release.assets | Where-Object { $_.name -match '_x64.*\.exe$' } | Select-Object -First 1
if (-not $asset) { Stop-Install 'A Windows Buzz installer was not found in the latest official release.' }
$buzzInstaller = Join-Path $env:TEMP $asset.name
Invoke-WebRequest $asset.browser_download_url -OutFile $buzzInstaller
Start-Process -FilePath $buzzInstaller -Wait

Write-Step 'Configuring local Ollama'
$ollama = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollama) { Stop-Install 'Ollama is not available on PATH. Restart PowerShell, then run setup again.' }
Start-Process -FilePath $ollama.Source -ArgumentList 'serve' -WindowStyle Hidden -ErrorAction SilentlyContinue
for ($try = 0; $try -lt 30; $try++) {
  try { Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' | Out-Null; break } catch { Start-Sleep -Seconds 1 }
}
try { Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' | Out-Null } catch { Stop-Install 'Ollama did not become available.' }

if ($Lane -eq 'OPNDRM-APP') {
  Write-Step 'Creating the Open Dream App workspace on the Desktop'
  $target = Join-Path ([Environment]::GetFolderPath('Desktop')) 'OPNDRM APP'
  if (Test-Path -LiteralPath $target) { Stop-Install "Workspace already exists at $target." }
  New-Item -ItemType Directory -Path $target | Out-Null
  Set-Content -LiteralPath (Join-Path $target 'README.md') -Value "# Open Dream App`n`nA fresh Open Dream Prime workspace." -Encoding utf8
} else {
  Write-Step 'Getting the team project and creating the workspace'
  $repo = if ($Lane -eq 'ADAM') { 'https://github.com/opndrm/ADAM.git' } else { 'https://github.com/frnklyone/frnkly-one-v2.git' }
  $target = Join-Path $env:USERPROFILE "OpenDream\$Lane"
  if (Test-Path -LiteralPath $target) { Stop-Install "Workspace already exists at $target." }
  New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
  git clone $repo $target
  if ($LASTEXITCODE -ne 0) { Stop-Install 'Could not clone the team project.' }
}

$providerFile = Join-Path $PrimeConfig 'models.json'
New-Item -ItemType Directory -Path $PrimeConfig -Force | Out-Null
$models = @((Invoke-RestMethod 'http://127.0.0.1:11434/api/tags').models | ForEach-Object { @{ id = $_.name } })
$provider = @{ providers = @{ ollama = @{ baseUrl = 'http://127.0.0.1:11434/v1'; api = 'openai-completions'; apiKey = 'ollama'; compat = @{ supportsDeveloperRole = $false; supportsReasoningEffort = $false }; models = $models } } }
$provider | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $providerFile -Encoding utf8

$session = "opndrm-$($Lane.ToLower().Replace('.', '-'))"
herdr --session $session workspace create --cwd $target --label "$Lane — PRIME" --focus
herdr --session $session tab create --cwd $target --label 'NO MISTAKES GATE' --no-focus

Write-Step 'Atomic Vault boundary'
Write-Host 'Atomic Vault is not installed from an unknown public source. The employee completes the team-approved Atomic Vault and CBF Remote owner-trust step directly.'
Write-Host "`nReady: $Lane workspace created. HERDR is Windows preview; No Mistakes is installed but no Gate run was started. Run /reload in Prime Agent to refresh the Open Dream Prime skill."
