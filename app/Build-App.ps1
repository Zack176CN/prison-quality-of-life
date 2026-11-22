[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$CatalogPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) { $OutputPath = Join-Path $project 'Prison QoL.exe' }
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if (-not $CatalogPath) { $CatalogPath = Join-Path $project 'patches.json' }
$catalog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CatalogPath)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'The Windows .NET Framework 4.x compiler was not found.'
}
if (-not (Test-Path -LiteralPath $catalog -PathType Leaf)) {
    throw 'Run build_patch_catalog.py before compiling the application.'
}
$manifest = Join-Path $PSScriptRoot 'PrisonQoL.manifest'
$tyrNotice = Join-Path $project 'features/staff_morale_decay/TYR-LICENSE.txt'
$compilerArgs = @(
    '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/codepage:65001',
    "/out:$OutputPath", "/win32manifest:$manifest", "/resource:$catalog,PrisonQoL.patches.json",
    "/resource:$tyrNotice,PrisonQoL.Tyr-MIT.txt",
    '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll', '/reference:System.Web.Extensions.dll'
)
$sourceFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cs' -File | Sort-Object Name | ForEach-Object FullName)
& $compiler @compilerArgs @sourceFiles
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Get-Item -LiteralPath $OutputPath | Select-Object FullName,Length
