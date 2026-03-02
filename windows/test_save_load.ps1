# NEON FLORA — Save/Load Integrity Test (S-8)
# Tests: Play games → Save state → Kill → Restart → Load → Verify state integrity

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$GODOT = "C:\Godot\Godot_v4.3-stable_win64.exe"
$PROJECT = "C:\xampp\htdocs\rpg_game\neon_flora"
$SCREENSHOT_DIR = "$PROJECT\windows\screenshots"
$LOG_FILE = "$PROJECT\windows\godot_test.log"
$STATE_FILE = "$PROJECT\windows\debug_state.json"
$SAVE_FILE = "$env:APPDATA\Godot\app_userdata\NEON FLORA\neonflora_save.json"

if (!(Test-Path $SCREENSHOT_DIR)) { New-Item -ItemType Directory -Path $SCREENSHOT_DIR | Out-Null }

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32SL {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
}
'@
$script:godotHwnd = [IntPtr]::Zero
$script:proc = $null

function Abort($reason) {
    Write-Host "`n!!! TEST ABORTED: $reason !!!" -ForegroundColor Red
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
            [Win32SL]::SetForegroundWindow($script:godotHwnd) | Out-Null
            Start-Sleep -Milliseconds 50
            $fg = [Win32SL]::GetForegroundWindow()
            if ($fg -eq $script:godotHwnd) { return }
            Start-Sleep -Milliseconds 100
        }
    }
}

$script:VK_MAP = @{
    " " = 0x20; "b" = 0x42; "z" = 0x5A; "x" = 0x58; "c" = 0x43
    "p" = 0x50; "d" = 0x44; "r" = 0x52; "t" = 0x54
    "ENTER" = 0x0D
}

function PressKey($key) {
    FocusGodot
    $vk = $script:VK_MAP[$key]
    if ($null -eq $vk) { $vk = [int][char]$key.ToUpper() }
    [Win32SL]::keybd_event([byte]$vk, 0, 0, 0)
    Start-Sleep -Milliseconds 30
    [Win32SL]::keybd_event([byte]$vk, 0, 2, 0)
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

function WaitForReady($label, $timeoutMs = 15000) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $stoppingRetries = 0
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        CheckProcess
        $st = DumpState
        if ($st) {
            $gs = $st.game_state
            if ($gs -eq "IDLE" -or $gs -eq "BONUS" -or $gs -eq "RT") {
                return $st
            }
            if ($gs -eq "STOPPING" -or $gs -eq "SPINNING") {
                $stoppingRetries++
                if ($stoppingRetries -ge 3) {
                    Write-Host "    Retrying stop keys (state=$gs, attempt=$stoppingRetries)..." -ForegroundColor Yellow
                    PressKey "z"; Start-Sleep -Milliseconds 200
                    PressKey "x"; Start-Sleep -Milliseconds 200
                    PressKey "c"; Start-Sleep -Milliseconds 200
                }
            }
        }
        Start-Sleep -Milliseconds 400
    }
    Abort "Game did not return to ready state within ${timeoutMs}ms at [$label]"
}

function PlayOneGame($label) {
    CheckProcess
    $st = WaitForReady "pre_$label"
    PressKey "b"
    Start-Sleep -Milliseconds 400
    PressKey " "
    Start-Sleep -Milliseconds 700
    PressKey "z"
    Start-Sleep -Milliseconds 500
    PressKey "x"
    Start-Sleep -Milliseconds 500
    PressKey "c"
    $stPost = WaitForReady "post_$label"
    return $stPost
}

function LaunchGame() {
    $script:godotHwnd = [IntPtr]::Zero
    $script:proc = Start-Process -FilePath $GODOT `
        -ArgumentList "--path `"$PROJECT`" --verbose" `
        -PassThru `
        -RedirectStandardError $LOG_FILE
    Start-Sleep -Seconds 4
    CheckProcess
    PressKey " "
    Start-Sleep -Seconds 3
}

try {
    Write-Host "=== NEON FLORA - Save/Load Integrity Test ==="

    if (Test-Path $LOG_FILE) { Remove-Item $LOG_FILE }
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE }

    # --- Phase 1: Play and save ---
    Write-Host "`n--- Phase 1: Play and build state ---"
    LaunchGame

    # Add credit
    PressKey "t"
    Start-Sleep -Milliseconds 500

    # Play 5 games to build non-trivial state
    for ($g = 1; $g -le 5; $g++) {
        Write-Host "  Playing game $g..."
        PlayOneGame "save_g$g" | Out-Null
    }

    # Trigger a BIG bonus to add bonus counts
    PressKey "d"
    Start-Sleep -Milliseconds 500
    # Play 3 games in bonus
    for ($g = 1; $g -le 3; $g++) {
        PlayOneGame "save_big_$g" | Out-Null
    }

    # Record pre-save state
    $preSave = DumpState
    Write-Host "`n  Pre-save state:" -ForegroundColor Cyan
    Write-Host "    credit=$([int]$preSave.credit)"
    Write-Host "    total_games=$([int]$preSave.total_games)"
    Write-Host "    big_count=$([int]$preSave.big_count)"
    Write-Host "    reg_count=$([int]$preSave.reg_count)"
    Write-Host "    total_in=$([int]$preSave.total_in)"
    Write-Host "    total_out=$([int]$preSave.total_out)"
    TakeScreenshot "sl_01_pre_save" | Out-Null

    # --- Phase 2: Kill game ---
    Write-Host "`n--- Phase 2: Kill game (simulating crash/close) ---"
    Start-Sleep -Seconds 1  # Allow auto-save
    if ($script:proc -and !$script:proc.HasExited) { $script:proc.Kill() }
    Start-Sleep -Seconds 2

    # Check save file exists
    if (Test-Path $SAVE_FILE) {
        Write-Host "  Save file found: $SAVE_FILE" -ForegroundColor Green
        $saveContent = Get-Content $SAVE_FILE -Raw
        Write-Host "  Save data: $saveContent" -ForegroundColor Cyan
    } else {
        Write-Host "  WARNING: Save file not found at $SAVE_FILE" -ForegroundColor Yellow
        # Try alternative paths
        $altSave = "$env:APPDATA\Godot\app_userdata\neon_flora\save_data.json"
        if (Test-Path $altSave) {
            Write-Host "  Found at alt path: $altSave" -ForegroundColor Green
        }
    }

    # --- Phase 3: Restart and verify ---
    Write-Host "`n--- Phase 3: Restart and verify state ---"
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE }
    LaunchGame

    # Give time for auto-load
    Start-Sleep -Seconds 2
    $postLoad = DumpState
    TakeScreenshot "sl_02_post_load" | Out-Null

    if ($null -eq $postLoad) { Abort "Could not get state after restart" }

    Write-Host "`n  Post-load state:" -ForegroundColor Cyan
    Write-Host "    credit=$([int]$postLoad.credit)"
    Write-Host "    total_games=$([int]$postLoad.total_games)"
    Write-Host "    big_count=$([int]$postLoad.big_count)"
    Write-Host "    reg_count=$([int]$postLoad.reg_count)"
    Write-Host "    total_in=$([int]$postLoad.total_in)"
    Write-Host "    total_out=$([int]$postLoad.total_out)"

    # --- Phase 4: Compare ---
    Write-Host "`n--- Phase 4: State comparison ---"
    $failures = @()

    # Credit may differ slightly if bonus was in progress, but should be close
    $creditDiff = [Math]::Abs([int]$postLoad.credit - [int]$preSave.credit)
    if ($creditDiff -gt 100) {
        $failures += "credit: $([int]$preSave.credit) -> $([int]$postLoad.credit) (diff=$creditDiff)"
    }

    # These should be exact matches
    if ([int]$postLoad.big_count -ne [int]$preSave.big_count) {
        $failures += "big_count: $([int]$preSave.big_count) -> $([int]$postLoad.big_count)"
    }
    if ([int]$postLoad.reg_count -ne [int]$preSave.reg_count) {
        $failures += "reg_count: $([int]$preSave.reg_count) -> $([int]$postLoad.reg_count)"
    }
    if ([int]$postLoad.total_in -ne [int]$preSave.total_in) {
        $failures += "total_in: $([int]$preSave.total_in) -> $([int]$postLoad.total_in)"
    }
    if ([int]$postLoad.total_out -ne [int]$preSave.total_out) {
        $failures += "total_out: $([int]$preSave.total_out) -> $([int]$postLoad.total_out)"
    }

    if ($failures.Count -gt 0) {
        Write-Host "  FAILURES:" -ForegroundColor Red
        foreach ($f in $failures) { Write-Host "    - $f" -ForegroundColor Red }
        Abort "State integrity check failed with $($failures.Count) mismatches"
    }

    Write-Host "  All state values match!" -ForegroundColor Green

    TakeScreenshot "sl_03_final" | Out-Null

    Write-Host "`n============================================"
    Write-Host "  ALL SAVE/LOAD TESTS PASSED" -ForegroundColor Green
    Write-Host "============================================"

} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($script:proc -and !$script:proc.HasExited) { $script:proc.Kill() }
    Write-Host "Screenshots: $SCREENSHOT_DIR"
}
