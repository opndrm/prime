param(
  [ValidateSet('ADAM', 'FRNKLY.ONE', 'OPNDRM-APP')]
  [Parameter(Mandatory = $true)]
  [string]$Lane
)

$ErrorActionPreference = 'Stop'
$workspace = Join-Path ([System.IO.Path]::GetTempPath()) "opndrm-prime-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $workspace | Out-Null
try {
  $archive = Join-Path $workspace 'prime.tar.gz'
  Invoke-WebRequest 'https://codeload.github.com/opndrm/prime/tar.gz/refs/heads/main' -OutFile $archive
  tar.exe -xzf $archive -C $workspace
  $source = Get-ChildItem -LiteralPath $workspace -Directory | Where-Object { $_.Name -like 'prime-*' } | Select-Object -First 1
  if (-not $source) { throw 'The Open Dream Prime package could not be unpacked.' }
  & (Join-Path $source.FullName 'scripts\install-windows.ps1') -Lane $Lane
} finally {
  Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction SilentlyContinue
}
