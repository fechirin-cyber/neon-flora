# M-4: BIG/REG Bonus Cycle Test (4.1s wait timer aware)
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Input {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    public const byte VK_B = 0x42;
    public const byte VK_SPACE = 0x20;
    public const byte VK_Z = 0x5A;
    public const byte VK_X = 0x58;
    public const byte VK_C = 0x43;
    public const byte VK_D = 0x44;
    public const byte VK_R = 0x52;
    public const byte VK_T = 0x54;
    public const byte VK_P = 0x50;
}
"@

function PressKey($vk) {
    [Win32Input]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [Win32Input]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
}

function PlayOneGame {
    PressKey([Win32Input]::VK_B)
    Start-Sleep -Milliseconds 200
    PressKey([Win32Input]::VK_SPACE)
    # Wait for 4.1s wait timer + 0.4s delay + margin
    Start-Sleep -Milliseconds 5000
    PressKey([Win32Input]::VK_Z)
    Start-Sleep -Milliseconds 300
    PressKey([Win32Input]::VK_X)
    Start-Sleep -Milliseconds 300
    PressKey([Win32Input]::VK_C)
    Start-Sleep -Milliseconds 500
}

function DumpState {
    $path = Join-Path $PSScriptRoot "debug_state.json"
    Remove-Item $path -ErrorAction SilentlyContinue
    PressKey([Win32Input]::VK_P)
    Start-Sleep -Milliseconds 500
    if (Test-Path $path) {
        return Get-Content $path -Raw | ConvertFrom-Json
    }
    return $null
}

# Delete save data for clean start
$savePath = Join-Path $env:APPDATA "Godot\app_userdata\NEON FLORA\save.json"
Remove-Item $savePath -ErrorAction SilentlyContinue

# Launch game (--auto-test で音量最小)
$proc = Start-Process -FilePath (Join-Path $PSScriptRoot "neon_flora.exe") -ArgumentList "-- --auto-test" -PassThru
Start-Sleep -Seconds 4
[Win32Input]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500

$results = @()

# Test 1: Basic game cycle (3 games, clean state)
Write-Host "=== Test 1: Basic Game Cycle ==="
PressKey([Win32Input]::VK_T)
Start-Sleep -Milliseconds 300
for ($i = 0; $i -lt 3; $i++) {
    PlayOneGame
    Start-Sleep -Milliseconds 200
}
$state = DumpState
if ($state) {
    $pass = ($state.total_games -ge 3) -and ($state.game_state -eq "IDLE" -or $state.game_state -eq "RT")
    $results += "Test1_BasicCycle: $(if($pass){'PASS'}else{'FAIL'}) (games=$($state.total_games), state=$($state.game_state), credit=$($state.credit))"
} else {
    $results += "Test1_BasicCycle: FAIL (no state)"
}
Write-Host $results[-1]

# Test 2: BIG Bonus start + game count
Write-Host "=== Test 2: BIG Bonus ==="
PressKey([Win32Input]::VK_D)
Start-Sleep -Milliseconds 500
$state = DumpState
$bigStarted = $state -and ($state.bonus_type -eq "BIG")
$results += "Test2_BIGStart: $(if($bigStarted){'PASS'}else{'FAIL'}) (type=$($state.bonus_type), state=$($state.game_state))"
Write-Host $results[-1]

# Play 5 BIG games and verify games are counting
$prevGames = if ($state) { $state.bonus_games_played } else { 0 }
for ($i = 0; $i -lt 5; $i++) {
    PlayOneGame
}
$state = DumpState
$gamesIncremented = $state -and ($state.bonus_games_played -gt $prevGames)
$results += "Test2_BIGGames: $(if($gamesIncremented){'PASS'}else{'FAIL'}) (played=$($state.bonus_games_played), payout=$($state.bonus_payout))"
Write-Host $results[-1]

# Kill and restart for REG test (clean state)
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Remove-Item $savePath -ErrorAction SilentlyContinue

$proc = Start-Process -FilePath (Join-Path $PSScriptRoot "neon_flora.exe") -ArgumentList "-- --auto-test" -PassThru
Start-Sleep -Seconds 4
[Win32Input]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500

# Test 3: REG Bonus start + game count
Write-Host "=== Test 3: REG Bonus ==="
PressKey([Win32Input]::VK_T)
Start-Sleep -Milliseconds 300
PressKey([Win32Input]::VK_R)
Start-Sleep -Milliseconds 500
$state = DumpState
$regStarted = $state -and ($state.bonus_type -eq "REG")
$results += "Test3_REGStart: $(if($regStarted){'PASS'}else{'FAIL'}) (type=$($state.bonus_type), state=$($state.game_state))"
Write-Host $results[-1]

# Play 5 REG games
$prevGames = if ($state) { $state.bonus_games_played } else { 0 }
for ($i = 0; $i -lt 5; $i++) {
    PlayOneGame
}
$state = DumpState
$gamesIncremented = $state -and ($state.bonus_games_played -gt $prevGames)
$results += "Test3_REGGames: $(if($gamesIncremented){'PASS'}else{'FAIL'}) (played=$($state.bonus_games_played), payout=$($state.bonus_payout))"
Write-Host $results[-1]

# Verify no RT during REG
$noRt = $state -and (-not $state.rt_active)
$results += "Test3_NoRT: $(if($noRt){'PASS'}else{'FAIL'}) (rt=$($state.rt_active))"
Write-Host $results[-1]

# Summary
Write-Host "`n=== RESULTS ==="
$allPass = $true
foreach ($r in $results) {
    Write-Host $r
    if ($r -match "FAIL") { $allPass = $false }
}
Write-Host "Overall: $(if($allPass){'ALL PASS'}else{'SOME FAILED'})"

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
exit $(if($allPass){0}else{1})
