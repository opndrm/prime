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
function Ensure-HerdrSession([string]$SessionName, [string]$WorkspacePath) {
  # HERDR workspace and tab commands use the named session socket. They do not
  # start that socket themselves, so every lane needs its own server first.
  herdr --session $SessionName status server *> $null
  if ($LASTEXITCODE -eq 0) { return }

  $herdrCommand = Get-Command herdr -ErrorAction SilentlyContinue
  if (-not $herdrCommand) { Stop-Install 'HERDR is not available to start the selected personal session.' }
  $herdrStateDirectory = Join-Path $env:LOCALAPPDATA 'OPNDRM\Prime\logs'
  New-Item -ItemType Directory -Path $herdrStateDirectory -Force | Out-Null
  $herdrLog = Join-Path $herdrStateDirectory "$SessionName-herdr.log"
  Write-Step "Starting the local HERDR session: $SessionName"
  try {
    Start-Process -FilePath $herdrCommand.Source -ArgumentList @('--session', $SessionName, 'server') -RedirectStandardOutput $herdrLog -RedirectStandardError "$herdrLog.err" -WindowStyle Hidden | Out-Null
  } catch {
    Stop-Install "HERDR could not start the $SessionName session. The selected workspace at $WorkspacePath was kept, but no PRIME workspace or No Mistakes Gate was created. Setup is not complete. Inspect $herdrLog."
  }
  for ($try = 0; $try -lt 30; $try++) {
    herdr --session $SessionName status server *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Start-Sleep -Seconds 1
  }
  Stop-Install "HERDR could not start or attach the $SessionName session. The selected workspace at $WorkspacePath was kept, but no PRIME workspace or No Mistakes Gate was created. Setup is not complete. Open WezTerm and run 'herdr --session $SessionName' to retry the personal session, or inspect $herdrLog."
}
function Start-HerdrWorkspace([string]$SessionName, [string]$WorkspacePath) {
  $weztermCommand = Get-Command wezterm -ErrorAction SilentlyContinue
  if (-not $weztermCommand) { Stop-Install 'WezTerm is not available to display the HERDR workspace. Setup is not complete and no Ready message was shown.' }
  Write-Step "Opening WezTerm in the $SessionName HERDR workspace"
  try {
    & $weztermCommand.Source start --cwd $WorkspacePath --workspace $SessionName -- herdr --session $SessionName
    if ($LASTEXITCODE -ne 0) { throw "wezterm exited with code $LASTEXITCODE" }
  } catch {
    Stop-Install "HERDR workspace was created, but WezTerm could not attach it visibly. Setup is not complete and no Ready message was shown. Open WezTerm and run 'herdr --session $SessionName' from $WorkspacePath after fixing WezTerm."
  }
}

if ([string]::IsNullOrWhiteSpace($env:OPNDRM_PROJECTS_DIR)) {
  $ProjectsRoot = Join-Path $env:USERPROFILE 'OPNDRM'
} else {
  $ProjectsRoot = $env:OPNDRM_PROJECTS_DIR
}

switch ($Lane) {
  'ADAM' {
    $PrivateRepository = 'opndrm/ADAM'
    $repo = 'https://github.com/opndrm/ADAM.git'
    $target = Join-Path $ProjectsRoot 'ADAM'
  }
  'FRNKLY.ONE' {
    $PrivateRepository = 'opndrm/Frnkly.one'
    $repo = 'https://github.com/opndrm/Frnkly.one.git'
    $target = Join-Path $ProjectsRoot 'FRNKLY.ONE'
  }
  'OPNDRM-APP' {
    $PrivateRepository = $null
    $repo = $null
    $target = Join-Path ([Environment]::GetFolderPath('Desktop')) 'OPNDRM APP'
  }
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator) {
  Write-Host 'Open Dream Prime needs Windows administrator approval to install its system tools.'
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Lane', $Lane)
  exit
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Step 'Opening Microsoft Store for Windows App Installer'
  Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
  Stop-Install 'Install or update Windows App Installer in Microsoft Store, reopen PowerShell, and run this same Open Dream Prime command again.'
}

Write-Step 'Installing Git Bash, Node, GitHub CLI, WezTerm, and Ollama'
Install-Winget 'Git.Git'
Install-Winget 'OpenJS.NodeJS.LTS'
Install-Winget 'GitHub.cli'
Install-Winget 'wez.wezterm'
Install-Winget 'Ollama.Ollama'
Refresh-Path

if ($Lane -ne 'OPNDRM-APP') {
  gh auth status --hostname github.com *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Step 'Sign in to your own GitHub account'
    Write-Host 'GitHub CLI will open GitHub’s official device authorization flow. Sign in with your own GitHub account and enter the one-time code only at GitHub’s official device page. No shared Open Dream credential, personal access token, or GitHub administrator repository access is used.'
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Stop-Install 'GitHub sign-in was not completed. Sign in with your own GitHub account and run this installer again.' }
    gh auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) { Stop-Install 'GitHub is not signed in for this Windows account.' }
  }
  $GitHubUsername = gh api --hostname github.com user --jq '.login' 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($GitHubUsername)) { Stop-Install 'GitHub could not identify the signed-in account. Sign in with your own GitHub account and run this installer again.' }
  Write-Host "GitHub is signed in as $GitHubUsername."
  gh api --hostname github.com "repos/$PrivateRepository" --silent *> $null
  if ($LASTEXITCODE -ne 0) { Stop-Install "Your GitHub account cannot read $PrivateRepository. Stop here without cloning. Ask the repository owner to invite this personal GitHub account as a normal collaborator with the repository access needed for $Lane, then run this installer again. No administrator role, shared account, token, or credential is required." }
  gh auth setup-git --hostname github.com
  if ($LASTEXITCODE -ne 0) { Stop-Install 'GitHub could not configure secure Git access for this Windows account.' }
}
# The public OPNDRM-APP lane never starts device authorization. Later public
# GitHub downloads must fail with guidance instead of opening a sign-in prompt.
$env:GH_PROMPT_DISABLED = '1'

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
if ($LASTEXITCODE -ne 0) { Stop-Install 'The Open Dream Prime GitHub package did not install. Check your network and Prime Agent setup, then run this installer again.' }
$primeAgentHelp = prime-agent --help 2>&1
if ($LASTEXITCODE -ne 0) { Stop-Install 'Prime Agent stopped responding after the Open Dream Prime package install. Restart Prime Agent, then run this installer again.' }
Write-Host 'Open Dream Prime GitHub package installed successfully. It loads when Prime Agent starts or after /reload; setup will continue now.'

Write-Step 'Installing No Mistakes and Buzz'
Invoke-RestMethod 'https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.ps1' | Invoke-Expression
$release = Invoke-RestMethod 'https://api.github.com/repos/block/buzz/releases/latest'
$asset = $release.assets | Where-Object { $_.name -match '_x64.*\.exe$' } | Select-Object -First 1
if (-not $asset) { Stop-Install 'A Windows Buzz installer was not found in the latest official release.' }
$buzzInstaller = Join-Path $env:TEMP $asset.name
Invoke-WebRequest $asset.browser_download_url -OutFile $buzzInstaller
Write-Host 'The official Buzz installer window is opening now. Complete it, then this installer continues.'
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
  if (Test-Path -LiteralPath $target) { Stop-Install "Workspace already exists at $target." }
  New-Item -ItemType Directory -Path $target | Out-Null
  Set-Content -LiteralPath (Join-Path $target 'README.md') -Value "# Open Dream App`n`nA fresh Open Dream Prime workspace." -Encoding utf8
} else {
  Write-Step 'Getting the team project and creating the workspace'
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
Ensure-HerdrSession -SessionName $session -WorkspacePath $target
herdr --session $session workspace create --cwd $target --label "$Lane — PRIME" --focus
if ($LASTEXITCODE -ne 0) { Stop-Install "HERDR could not create the PRIME workspace. Setup is not complete and no Ready message was shown. The selected workspace at $target was kept untouched." }
herdr --session $session tab create --cwd $target --label 'NO MISTAKES GATE — RESERVED (INACTIVE)' --no-focus
if ($LASTEXITCODE -ne 0) { Stop-Install 'HERDR could not create the reserved inactive No Mistakes Gate. Setup is not complete and no Ready message was shown. No Gate run was started.' }

Write-Step 'Preparing personal Buzz onboarding'
$buzzStateDirectory = Join-Path $env:APPDATA 'OPNDRM\Prime'
New-Item -ItemType Directory -Path $buzzStateDirectory -Force | Out-Null
$buzzStateFile = Join-Path $buzzStateDirectory "$session-buzz-onboarding.json"
$buzzState = [ordered]@{
  status = 'waiting-for-owner'
  workspace = $Lane
  workspace_path = $target
  repository = $PrivateRepository
  suggested_agent_name = "PRIME — $Lane"
  suggested_agent_role = 'root workspace agent'
  issue_tracker = 'https://github.com/opndrm/prime/issues'
  next_owner_action = 'Sign in to Buzz, create or connect the named agent, then save its approved identifier in your Atomic Vault OPNDRM entry.'
}
$buzzState | ConvertTo-Json | Set-Content -LiteralPath $buzzStateFile -Encoding utf8
Start-HerdrWorkspace -SessionName $session -WorkspacePath $target
$buzzApp = Get-StartApps | Where-Object { $_.Name -eq 'Buzz' } | Select-Object -First 1
if ($buzzApp) {
  Start-Process "shell:AppsFolder\$($buzzApp.AppID)"
  Write-Host "Buzz has opened for $Lane. Complete your personal Buzz sign-in, then use $buzzStateFile to create or connect your named agent."
} else {
  Write-Host "Buzz is installed. Open it from Start, complete your personal sign-in, then use $buzzStateFile to create or connect your named agent for $Lane."
}

Write-Step 'Atomic Vault boundary'
Write-Host 'Atomic Vault is not installed from an unknown public source. The employee completes the team-approved Atomic Vault and CBF Remote owner-trust step directly.'
Write-Host "`nReady: WezTerm is attached to the $session HERDR workspace rooted at $target. PRIME is the main workspace and NO MISTAKES GATE is reserved and inactive. No Gate run was started. Buzz onboarding is waiting for the employee’s personal sign-in and Vault approval. Run /reload in Prime Agent to refresh the Open Dream Prime skill."
