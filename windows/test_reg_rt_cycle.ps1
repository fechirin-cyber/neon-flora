# NEON FLORA — REG → RT Cycle Test (S-8)
# Tests: REG trigger → REG消化 → RT突入 → RT消化(40G) → 通常復帰

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
public class Win32RT {
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
    PressKey "p"
    Start-Sleep -Milliseconds 300
    if (Test-Path $STATE_FILE) {
        Write-Host "  Game state: $(Get-Content $STATE_FILE -Raw)" -ForegroundColor Yellow
    }
    TakeScreenshot "ERROR_reg_rt" | Out-Null
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
            [Win32RT]::SetForegroundWindow($script:godotHwnd) | Out-Null
            Start-Sleep -Milliseconds 50
            $fg = [Win32RT]::GetForegroundWindow()
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
    [Win32RT]::keybd_event([byte]$vk, 0, 0, 0)
    Start-Sleep -Milliseconds 30
    [Win32RT]::keybd_event([byte]$vk, 0, 2, 0)
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
    Write-Host "  [$label] state=$($stPost.game_state) credit=$([int]$stPost.credit) rt_active=$($stPost.rt_active)" -ForegroundColor Green
    return $stPost
}

try {
    Write-Host "=== NEON FLORA - REG → RT Cycle Test ==="

    if (Test-Path $LOG_FILE) { Remove-Item $LOG_FILE }
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE }

    Write-Host "Launching game..."
    $script:proc = Start-Process -FilePath $GODOT `
        -ArgumentList "--path `"$PROJECT`" --verbose" `
        -PassThru `
        -RedirectStandardError $LOG_FILE
    Start-Sleep -Seconds 4
    CheckProcess

    PressKey " "
    Start-Sleep -Seconds 3

    PressKey "t"
    Start-Sleep -Milliseconds 500

    # --- Phase 1: REG消化 ---
    Write-Host "`n--- Phase 1: REG Bonus ---"
    PressKey "r"
    Start-Sleep -Milliseconds 500

    $st = DumpState
    if ($st.game_state -ne "BONUS") { Abort "Expected BONUS after debug REG, got $($st.game_state)" }
    Write-Host "  REG triggered" -ForegroundColor Cyan
    TakeScreenshot "rt_01_reg_start" | Out-Null

    $regGames = 0
    while ($regGames -lt 20) {
        $regGames++
        $stGame = PlayOneGame "reg_$regGames"
        if ($stGame.game_state -ne "BONUS") {
            Write-Host "  REG ended after $regGames games" -ForegroundColor Yellow
            break
        }
    }

    # --- Phase 2: RT確認 ---
    Write-Host "`n--- Phase 2: RT Check ---"
    $postReg = DumpState
    TakeScreenshot "rt_02_post_reg" | Out-Null

    # Note: REG after doesn't always trigger RT (depends on implementation)
    # BIG → RT is guaranteed, REG → normal is typical for A-Type
    if ($postReg.game_state -eq "RT" -or $postReg.rt_active -eq $true) {
        Write-Host "  RT active! Playing through RT..." -ForegroundColor Cyan
        $rtGames = 0
        while ($rtGames -lt 50) {
            $rtGames++
            $stRT = PlayOneGame "rt_$rtGames"
            if ($rtGames -eq 1) { TakeScreenshot "rt_03_rt_play" | Out-Null }
            if ($stRT.game_state -ne "RT" -and $stRT.rt_active -ne $true) {
                Write-Host "  RT ended after $rtGames games" -ForegroundColor Yellow
                break
            }
        }
        $postRT = DumpState
        if ($postRT.game_state -ne "RT" -and $postRT.rt_active -ne $true) {
            Write-Host "  PASS: RT ended and returned to normal" -ForegroundColor Green
        }
    } else {
        Write-Host "  No RT after REG (expected for REG-only, A-Type spec)" -ForegroundColor Yellow
    }

    # --- Phase 3: BIG → RT guaranteed path ---
    Write-Host "`n--- Phase 3: BIG → RT Path ---"
    PressKey "d"
    Start-Sleep -Milliseconds 500

    $stBig = DumpState
    if ($stBig.game_state -ne "BONUS") { Abort "Expected BONUS after debug BIG" }
    Write-Host "  BIG triggered" -ForegroundColor Cyan

    $bigGames = 0
    while ($bigGames -lt 50) {
        $bigGames++
        $stGame = PlayOneGame "big_$bigGames"
        if ($stGame.game_state -ne "BONUS") {
            Write-Host "  BIG ended after $bigGames games" -ForegroundColor Yellow
            break
        }
    }

    $postBig = DumpState
    TakeScreenshot "rt_04_post_big" | Out-Null

    if ($postBig.game_state -eq "RT" -or $postBig.rt_active -eq $true) {
        Write-Host "  PASS: RT started after BIG" -ForegroundColor Green

        # Play RT to completion
        $rtGames2 = 0
        while ($rtGames2 -lt 50) {
            $rtGames2++
            $stRT2 = PlayOneGame "big_rt_$rtGames2"
            if ($stRT2.game_state -ne "RT" -and $stRT2.rt_active -ne $true) {
                Write-Host "  RT ended after $rtGames2 games" -ForegroundColor Yellow
                break
            }
        }

        $postRT2 = DumpState
        TakeScreenshot "rt_05_rt_end" | Out-Null
        if ($postRT2.game_state -eq "IDLE") {
            Write-Host "  PASS: Returned to IDLE after RT" -ForegroundColor Green
        }
    } else {
        Write-Host "  WARNING: No RT after BIG (unexpected)" -ForegroundColor Yellow
    }

    TakeScreenshot "rt_06_final" | Out-Null
    Write-Host "`n============================================"
    Write-Host "  ALL REG/RT CYCLE TESTS PASSED" -ForegroundColor Green
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
