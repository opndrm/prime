param([Parameter(Mandatory = $true)][string]$Lane)
if ($Lane -notin @('OPNDRM-APP', 'ADAM', 'FRNKLY.ONE')) { throw 'Choose OPNDRM-APP, ADAM, or FRNKLY.ONE.' }
throw 'Open Dream Prime Windows support is not released. This installer made no changes. Use the macOS workflow or wait for a real Windows-device validation.'
