# Flutter Setup and Run Script for PowerShell
# This script adds Flutter to PATH and runs the commands

# Common Flutter installation paths
$flutterPaths = @(
    "C:\flutter\bin",
    "$env:LOCALAPPDATA\flutter\bin",
    "$env:USERPROFILE\flutter\bin",
    "$env:ProgramFiles\flutter\bin"
)

# Find Flutter
$flutterPath = $null
foreach ($path in $flutterPaths) {
    if (Test-Path $path) {
        $flutterPath = $path
        break
    }
}

if ($null -eq $flutterPath) {
    Write-Host "Flutter not found in common locations. Please add Flutter to your PATH manually." -ForegroundColor Red
    Write-Host "Or run these commands in Command Prompt where Flutter is working:" -ForegroundColor Yellow
    Write-Host "  cd C:\Users\Adnan\Documents\GitHub\Ameenplus1" -ForegroundColor Cyan
    Write-Host "  flutter clean" -ForegroundColor Cyan
    Write-Host "  flutter pub get" -ForegroundColor Cyan
    Write-Host "  flutter run" -ForegroundColor Cyan
    exit 1
}

# Add Flutter to PATH for this session
$env:Path += ";$flutterPath"
Write-Host "Added Flutter to PATH: $flutterPath" -ForegroundColor Green

# Verify Flutter works
try {
    $flutterVersion = & flutter --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Flutter is working!" -ForegroundColor Green
    } else {
        throw "Flutter command failed"
    }
} catch {
    Write-Host "Flutter command failed. Please check your installation." -ForegroundColor Red
    exit 1
}

# Navigate to project directory
Set-Location "C:\Users\Adnan\Documents\GitHub\Ameenplus1"

# Run Flutter commands
Write-Host "`nCleaning Flutter project..." -ForegroundColor Yellow
& flutter clean

Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
& flutter pub get

Write-Host "`nRunning Flutter app..." -ForegroundColor Yellow
& flutter run
