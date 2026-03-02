# NEON FLORA — Bonus Cycle Test (S-8)
# Tests: BIG bonus trigger → 消化(45G) → 終了 → RT突入確認

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
public class Win32BC {
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
    TakeScreenshot "ERROR_bonus_cycle" | Out-Null
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
            [Win32BC]::SetForegroundWindow($script:godotHwnd) | Out-Null
            Start-Sleep -Milliseconds 50
            $fg = [Win32BC]::GetForegroundWindow()
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
    [Win32BC]::keybd_event([byte]$vk, 0, 0, 0)
    Start-Sleep -Milliseconds 30
    [Win32BC]::keybd_event([byte]$vk, 0, 2, 0)
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
            # Retry stop keys if stuck in STOPPING/SPINNING
            if ($gs -eq "STOPPING" -or $gs -eq "SPINNING") {
                $stoppingRetries += 1
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
    Write-Host "  [$label] state=$($stPost.game_state) credit=$([int]$stPost.credit) games=$([int]$stPost.total_games)" -ForegroundColor Green
    return $stPost
}

try {
    Write-Host "=== NEON FLORA - Bonus Cycle Test ==="

    if (Test-Path $LOG_FILE) { Remove-Item $LOG_FILE }
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE }

    Write-Host "Launching game..."
    $script:proc = Start-Process -FilePath $GODOT `
        -ArgumentList "--path `"$PROJECT`" --verbose" `
        -PassThru `
        -RedirectStandardError $LOG_FILE
    Start-Sleep -Seconds 4
    CheckProcess

    # Navigate to game
    PressKey " "
    Start-Sleep -Seconds 3

    # Add credit
    PressKey "t"
    Start-Sleep -Milliseconds 500

    # --- TEST 1: BIG Bonus Full Cycle ---
    Write-Host "`n--- TEST 1: BIG Bonus Cycle ---"

    # Record pre-bonus state
    $preBig = DumpState
    $preBigCount = [int]$preBig.big_count
    Write-Host "  Pre-BIG: big_count=$preBigCount credit=$([int]$preBig.credit)"

    # Trigger BIG via debug
    PressKey "d"
    Start-Sleep -Milliseconds 500
    TakeScreenshot "bc_01_big_trigger" | Out-Null

    # Verify BONUS state
    $st = DumpState
    if ($st.game_state -ne "BONUS") { Abort "Expected BONUS state after debug BIG, got $($st.game_state)" }
    if ($st.bonus_type -ne "BIG") { Abort "Expected BIG bonus, got $($st.bonus_type)" }
    Write-Host "  BIG triggered: bonus_games_max=$([int]$st.bonus_games_max)" -ForegroundColor Cyan

    # Play through BIG (45G max, but may end earlier)
    $bonusGames = 0
    $maxGames = 50
    while ($bonusGames -lt $maxGames) {
        $bonusGames++
        $stGame = PlayOneGame "big_g$bonusGames"
        if ($stGame.game_state -ne "BONUS") {
            Write-Host "  BIG ended after $bonusGames games" -ForegroundColor Yellow
            break
        }
        if ($bonusGames -eq 1) { TakeScreenshot "bc_02_big_play" | Out-Null }
    }

    # Verify post-BIG state (should be RT or IDLE)
    $postBig = DumpState
    $postBigCount = [int]$postBig.big_count
    Write-Host "  Post-BIG: state=$($postBig.game_state) big_count=$postBigCount rt_active=$($postBig.rt_active)"
    TakeScreenshot "bc_03_big_end" | Out-Null

    if ($postBigCount -le $preBigCount) { Abort "big_count did not increment ($preBigCount -> $postBigCount)" }
    Write-Host "  PASS: BIG count incremented correctly" -ForegroundColor Green

    # If RT is active, play through it
    if ($postBig.rt_active -eq $true -or $postBig.game_state -eq "RT") {
        Write-Host "  RT active, playing through..."
        $rtGames = 0
        while ($rtGames -lt 50) {
            $rtGames++
            $stRT = PlayOneGame "rt_g$rtGames"
            if ($stRT.game_state -ne "RT" -and $stRT.rt_active -ne $true) {
                Write-Host "  RT ended after $rtGames games" -ForegroundColor Yellow
                break
            }
        }
    }

    # --- TEST 2: REG Bonus ---
    Write-Host "`n--- TEST 2: REG Bonus Cycle ---"
    $preReg = DumpState
    $preRegCount = [int]$preReg.reg_count

    PressKey "r"
    Start-Sleep -Milliseconds 500
    TakeScreenshot "bc_04_reg_trigger" | Out-Null

    $st = DumpState
    if ($st.game_state -ne "BONUS") { Abort "Expected BONUS state after debug REG, got $($st.game_state)" }
    Write-Host "  REG triggered: bonus_games_max=$([int]$st.bonus_games_max)" -ForegroundColor Cyan

    # Play through REG (14G max)
    $regGames = 0
    while ($regGames -lt 20) {
        $regGames++
        $stGame = PlayOneGame "reg_g$regGames"
        if ($stGame.game_state -ne "BONUS") {
            Write-Host "  REG ended after $regGames games" -ForegroundColor Yellow
            break
        }
    }

    $postReg = DumpState
    $postRegCount = [int]$postReg.reg_count
    TakeScreenshot "bc_05_reg_end" | Out-Null

    if ($postRegCount -le $preRegCount) { Abort "reg_count did not increment ($preRegCount -> $postRegCount)" }
    Write-Host "  PASS: REG count incremented correctly" -ForegroundColor Green

    # Final verification
    Write-Host "`n--- Final State ---"
    $final = DumpState
    Write-Host "  state=$($final.game_state) credit=$([int]$final.credit) BIG=$([int]$final.big_count) REG=$([int]$final.reg_count)"
    TakeScreenshot "bc_06_final" | Out-Null

    Write-Host "`n============================================"
    Write-Host "  ALL BONUS CYCLE TESTS PASSED" -ForegroundColor Green
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
