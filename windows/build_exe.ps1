# NEON FLORA — Windows EXE Build Script
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "windows\build_exe.ps1"

param(
    [string]$GodotPath = "C:\Godot\Godot_v4.3-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$OutputExe = Join-Path $PSScriptRoot "neon_flora.exe"

Write-Host "=== NEON FLORA - Windows EXE Build ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectDir"
Write-Host "Output:  $OutputExe"
Write-Host ""

# Godot 実行ファイルの検索
$GodotCandidates = @(
    $GodotPath,
    "C:\Godot\Godot_v4.3-stable_win64.exe",
    "C:\Program Files\Godot\Godot_v4.3-stable_win64.exe",
    "C:\tools\godot\Godot_v4.3-stable_win64.exe"
)

$GodotExe = $null
foreach ($candidate in $GodotCandidates) {
    if (Test-Path $candidate) {
        $GodotExe = $candidate
        break
    }
}

if (-not $GodotExe) {
    Write-Host "ERROR: Godot not found. Please install Godot 4.3 or specify -GodotPath" -ForegroundColor Red
    exit 1
}

Write-Host "Godot: $GodotExe" -ForegroundColor Green

# EXE ビルド実行
Write-Host "Building Windows EXE..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $GodotExe `
    -ArgumentList "--headless --path `"$ProjectDir`" --export-debug `"Windows Desktop`" `"$OutputExe`"" `
    -Wait -PassThru -NoNewWindow

if (Test-Path $OutputExe) {
    $size = (Get-Item $OutputExe).Length / 1MB
    Write-Host ""
    Write-Host "Build SUCCESS!" -ForegroundColor Green
    Write-Host "Output: $OutputExe ($([math]::Round($size, 1)) MB)"
} else {
    Write-Host "Build FAILED (exit code: $($proc.ExitCode))" -ForegroundColor Red
    exit 1
}
