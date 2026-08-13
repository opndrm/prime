param(
  [ValidateSet('ADAM', 'FRNKLY.ONE')]
  [string]$Lane
)

$ErrorActionPreference = 'Stop'
if (-not $Lane) { throw 'Choose your assigned project: ADAM or FRNKLY.ONE.' }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Windows App Installer is required before Open Dream Prime can continue.' }

function Install-OpenDreamPackage([string]$Id) {
  winget install --exact --id $Id --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) { throw "Could not install $Id." }
}

Write-Host 'Open Dream Prime — Windows first-device preview'
Install-OpenDreamPackage 'Git.Git'
Install-OpenDreamPackage 'GitHub.cli'
Install-OpenDreamPackage 'wez.wezterm'
Install-OpenDreamPackage 'Ollama.Ollama'

Write-Host 'Baseline tools are ready. Prime Agent, HERDR, Buzz, No Mistakes, and Atomic Vault require their approved Windows compatibility sources before this preview creates a workspace.'
Write-Host "No project checkout or credential trust state was changed for $Lane."
