param(
    [string]$GodotPath = '',
    [Parameter(Mandatory=$true)][string]$ReleaseTemplate,
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$applicationDirectory = Join-Path $projectDirectory 'app'
if (-not $GodotPath) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $godotCommand) { throw 'Pass -GodotPath pointing to Godot 4.7.2 stable.' }
    $GodotPath = $godotCommand.Source
}
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectDirectory 'builds/windows' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$ReleaseTemplate = (Resolve-Path -LiteralPath $ReleaseTemplate).Path.Replace('\','/')
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$toolState = Join-Path $projectDirectory '.build-state'
New-Item -ItemType Directory -Path $toolState -Force | Out-Null
$previousAppData = $env:APPDATA
$previousLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $toolState 'roaming'
    $env:LOCALAPPDATA = Join-Path $toolState 'local'
    $version = & $GodotPath --version
    if ($version -notmatch '^4\.7\.2\.stable') { throw "Expected Godot 4.7.2 stable, got: $version" }
    $preset = @"
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="data/*.json"
exclude_filter="tests/*,export_templates/*,feature_profiles/*,script_templates/*,text_editor_themes/*"
export_path="../builds/windows/DotaComboArena.exe"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release="$ReleaseTemplate"
debug/export_console_wrapper=0
binary_format/architecture="x86_64"
binary_format/embed_pck=false
codesign/enable=false
application/modify_resources=true
application/file_version="0.6.6.0"
application/product_version="0.6.6.0"
application/company_name=""
application/product_name="Dota Combo Arena"
application/file_description="Keyboard warm-up trainer for Dota 2"
application/copyright=""
"@
    Set-Content -LiteralPath (Join-Path $applicationDirectory 'export_presets.cfg') -Value $preset -Encoding utf8
    & $GodotPath --headless --path $applicationDirectory --editor --quit --log-file (Join-Path $toolState 'import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    $exportFile = Join-Path $OutputDirectory 'DotaComboArena.exe'
    & $GodotPath --headless --path $applicationDirectory --export-release 'Windows Desktop' $exportFile --log-file (Join-Path $toolState 'export.log')
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exportFile)) { throw 'Windows export failed' }
    & $GodotPath --headless --path $applicationDirectory --script res://tests/write_notices.gd -- --notices-output=$(Join-Path $OutputDirectory 'GODOT-NOTICES.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Engine notices export failed' }
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs/START.md') -Destination (Join-Path $OutputDirectory 'START.md') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets/RESOURCE_SOURCES.md') -Destination (Join-Path $OutputDirectory 'RESOURCE_SOURCES.md') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets/STAGE3_ART_PROMPTS.md') -Destination (Join-Path $OutputDirectory 'STAGE3_ART_PROMPTS.md') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets/STAGE4_ART_PROMPTS.md') -Destination (Join-Path $OutputDirectory 'STAGE4_ART_PROMPTS.md') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE') -Destination (Join-Path $OutputDirectory 'LICENSE') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'THIRD_PARTY_NOTICES.md') -Destination (Join-Path $OutputDirectory 'THIRD_PARTY_NOTICES.md') -Force
    Copy-Item -LiteralPath (Join-Path $applicationDirectory 'assets/fonts/NotoSans-OFL.txt'),(Join-Path $applicationDirectory 'assets/fonts/CormorantSC-OFL.txt') -Destination $OutputDirectory -Force
    Get-FileHash -LiteralPath $exportFile,(Join-Path $OutputDirectory 'DotaComboArena.pck') -Algorithm SHA256 | ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" } | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding utf8
    Write-Output "BUILD_OK $exportFile"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
}
