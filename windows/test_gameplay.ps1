# NEON FLORA — Basic Gameplay Test (プリプロ)
# Tests: Launch → 3 games (BET→LEVER→STOP×3→判定→IDLE復帰)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$GODOT = "C:\Godot\Godot_v4.3-stable_win64.exe"
$PROJECT = "C:\xampp\htdocs\rpg_game\neon_flora"
$SCREENSHOT_DIR = "$PROJECT\windows\screenshots"
$LOG_FILE = "$PROJECT\windows\godot_test.log"
$STATE_FILE = "$PROJECT\windows\debug_state.json"

if (!(Test-Path $SCREENSHOT_DIR)) { New-Item -ItemType Directory -Path $SCREENSHOT_DIR | Out-Null }

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32NF {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
}
'@
$script:godotHwnd = [IntPtr]::Zero
$script:proc = $null

# === Helpers ===

function Abort($reason) {
    Write-Host "`n!!! TEST ABORTED: $reason !!!" -ForegroundColor Red
    PressKey "p"
    Start-Sleep -Milliseconds 300
    if (Test-Path $STATE_FILE) {
        Write-Host "  Game state: $(Get-Content $STATE_FILE -Raw)" -ForegroundColor Yellow
    }
    TakeScreenshot "ERROR_abort" | Out-Null
    if ($script:proc -and !$script:proc.HasExited) { $script:proc.Kill() }
    throw "Test aborted: $reason"
}

function CheckProcess() {
    if ($script:proc.HasExited) {
        Abort "Godot process exited unexpectedly (exit code: $($script:proc.ExitCode))"
    }
}

function FocusGodot() {
    if ($script:godotHwnd -eq [IntPtr]::Zero) {
        $procs = Get-Process | Where-Object { $_.MainWindowTitle -match "NEON FLORA" -or $_.MainWindowTitle -match "neon_flora" -or $_.MainWindowTitle -match "Godot" }
        if ($procs) { $script:godotHwnd = $procs[0].MainWindowHandle }
    }
    if ($script:godotHwnd -ne [IntPtr]::Zero) {
        for ($i = 0; $i -lt 3; $i++) {
            [Win32NF]::SetForegroundWindow($script:godotHwnd) | Out-Null
            Start-Sleep -Milliseconds 50
            $fg = [Win32NF]::GetForegroundWindow()
            if ($fg -eq $script:godotHwnd) { return }
            Start-Sleep -Milliseconds 100
        }
    }
}

$script:VK_MAP = @{
    " " = 0x20; "b" = 0x42; "z" = 0x5A; "x" = 0x58; "c" = 0x43
    "p" = 0x50; "d" = 0x44; "r" = 0x52; "t" = 0x54
}

function PressKey($key) {
    FocusGodot
    $vk = $script:VK_MAP[$key]
    if ($null -eq $vk) { $vk = [int][char]$key.ToUpper() }
    [Win32NF]::keybd_event([byte]$vk, 0, 0, 0)
    Start-Sleep -Milliseconds 30
    [Win32NF]::keybd_event([byte]$vk, 0, 2, 0)
    Start-Sleep -Milliseconds 100
}

function TakeScreenshot($name) {
    Start-Sleep -Milliseconds 300
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $path = "$SCREENSHOT_DIR\$name.png"
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    return $path
}

function DumpState() {
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE -Force }
    PressKey "p"
    Start-Sleep -Milliseconds 400
    if (!(Test-Path $STATE_FILE)) { return $null }
    try { return (Get-Content $STATE_FILE -Raw | ConvertFrom-Json) }
    catch { return $null }
}

function WaitForReady($label, $timeoutMs = 5000) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        CheckProcess
        $st = DumpState
        if ($st) {
            $gs = $st.game_state
            if ($gs -eq "IDLE" -or $gs -eq "BONUS" -or $gs -eq "RT") {
                return $st
            }
        }
        Start-Sleep -Milliseconds 300
    }
    Abort "Game did not return to ready state within ${timeoutMs}ms at [$label]"
}

function PlayOneGame($label) {
    CheckProcess
    $st = WaitForReady "pre_$label"
    $gs = $st.game_state
    Write-Host "  [$label] pre-state=$gs credit=$([int]$st.credit)" -ForegroundColor Cyan

    # BET (B key)
    PressKey "b"
    Start-Sleep -Milliseconds 300

    # LEVER (SPACE)
    PressKey " "
    Start-Sleep -Milliseconds 500

    # Verify spinning
    CheckProcess
    $st2 = DumpState
    if ($st2 -and $st2.game_state -ne "SPINNING" -and $st2.game_state -ne "STOPPING") {
        # Retry: maybe lever didn't register
        PressKey "b"
        Start-Sleep -Milliseconds 200
        PressKey " "
        Start-Sleep -Milliseconds 500
    }

    # STOP L, C, R
    PressKey "z"
    Start-Sleep -Milliseconds 400
    PressKey "x"
    Start-Sleep -Milliseconds 400
    PressKey "c"

    # Wait for game to finish
    $stPost = WaitForReady "post_$label"
    TakeScreenshot $label | Out-Null

    Write-Host "  [$label] post-state=$($stPost.game_state) credit=$([int]$stPost.credit) games=$([int]$stPost.total_games) reels=[$($stPost.reel_positions -join ',')]" -ForegroundColor Green
}

try {
    Write-Host "=== NEON FLORA - Basic Gameplay Test ==="

    if (Test-Path $LOG_FILE) { Remove-Item $LOG_FILE }
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE }

    Write-Host "Launching game..."
    $script:proc = Start-Process -FilePath $GODOT `
        -ArgumentList "--path `"$PROJECT`" --verbose" `
        -PassThru `
        -RedirectStandardError $LOG_FILE
    Start-Sleep -Seconds 4
    CheckProcess

    TakeScreenshot "01_launch" | Out-Null
    Write-Host "Game launched" -ForegroundColor Green

    # Add credit for testing
    PressKey "t"
    Start-Sleep -Milliseconds 500

    for ($g = 1; $g -le 3; $g++) {
        Write-Host "Game $g..."
        PlayOneGame "game_$g"
    }

    # Final screenshot
    TakeScreenshot "final" | Out-Null

    Write-Host "`n============================================"
    Write-Host "  ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "============================================"

} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($script:proc -and !$script:proc.HasExited) { $script:proc.Kill() }
    if (Test-Path $LOG_FILE) {
        $errors = Select-String -Path $LOG_FILE -Pattern "SCRIPT ERROR" -SimpleMatch 2>$null
        if ($errors) {
            Write-Host "`n--- Godot Log Errors ---" -ForegroundColor Yellow
            foreach ($e in $errors) { Write-Host "  $($e.Line)" -ForegroundColor Yellow }
        }
    }
    Write-Host "Screenshots: $SCREENSHOT_DIR"
}
