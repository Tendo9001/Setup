# Windows Development Environment Setup Script (Tendo's Edition)
# Must run as Administrator

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "Starting Windows development environment setup..." -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# ============================================
# Virtualization check (for Docker)
# ============================================

function Test-VirtualMachinePlatformEnabled {
    try {
        $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
        if ($null -eq $vmPlatform) { return $false }
        return $vmPlatform.State -eq "Enabled"
    } catch {
        return $false
    }
}

function Test-PendingReboot {
    try {
        $updateKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        $cbsKey    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        return ((Test-Path $updateKey) -or (Test-Path $cbsKey))
    } catch { return $false }
}

$script:RebootRequired = $false

# Check Docker virtualization requirement
$vmPlatformEnabled = Test-VirtualMachinePlatformEnabled
$pendingReboot     = Test-PendingReboot

if (-not $vmPlatformEnabled) {
    Write-Host "Enabling VirtualMachinePlatform for Docker..." -ForegroundColor Yellow
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $script:RebootRequired = $true
    Write-Host "VirtualMachinePlatform enabled (restart required before Docker will work)" -ForegroundColor Yellow
} else {
    Write-Host "VirtualMachinePlatform already enabled" -ForegroundColor Green
}

if ($pendingReboot) {
    Write-Host "WARNING: System has a pending reboot, recommend restarting first" -ForegroundColor Yellow
    $script:RebootRequired = $true
}

# ============================================
# 1. Check winget
# ============================================

Write-Host ""
Write-Host "Checking winget..." -ForegroundColor Yellow
try {
    $wingetVersion = winget --version
    Write-Host "winget: $wingetVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: winget not found. Install App Installer from Microsoft Store: https://aka.ms/getwinget" -ForegroundColor Red
    exit 1
}

# ============================================
# 2. Install packages via winget
# ============================================

Write-Host ""
Write-Host "Installing packages..." -ForegroundColor Yellow

$wingetJsonPath = Join-Path $ScriptDir "setup.winget.json"

if (-not (Test-Path $wingetJsonPath)) {
    Write-Host "ERROR: setup.winget.json not found at $wingetJsonPath" -ForegroundColor Red
    exit 1
}

# Skip Docker if reboot is needed
$finalWingetPath = $wingetJsonPath
if ($script:RebootRequired) {
    Write-Host "Docker will be skipped until after reboot" -ForegroundColor Yellow
    $wingetContent = Get-Content $wingetJsonPath -Raw | ConvertFrom-Json
    foreach ($source in $wingetContent.Sources) {
        $source.Packages = @($source.Packages | Where-Object { $_.PackageIdentifier -notlike "*Docker*" })
    }
    $tempPath = Join-Path $env:TEMP "setup.winget.temp.json"
    $wingetContent | ConvertTo-Json -Depth 10 | Set-Content $tempPath -Encoding UTF8
    $finalWingetPath = $tempPath
}

try {
    winget import -i $finalWingetPath --accept-package-agreements --accept-source-agreements --ignore-versions
    Write-Host "Packages installed" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Some packages may have failed, check output above" -ForegroundColor Yellow
} finally {
    if ($finalWingetPath -ne $wingetJsonPath -and (Test-Path $finalWingetPath)) {
        Remove-Item $finalWingetPath -Force -ErrorAction SilentlyContinue
    }
}

# ============================================
# 3. Refresh PATH
# ============================================

Write-Host ""
Write-Host "Refreshing PATH..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Add common paths that may not be in PATH yet
function Add-ToPathIfNotExists {
    param([string]$NewPath)
    if (Test-Path $NewPath) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$NewPath*") {
            [Environment]::SetEnvironmentVariable("Path", $currentPath + ";" + $NewPath, "User")
            Write-Host "Added to PATH: $NewPath" -ForegroundColor Green
        }
    }
}

Add-ToPathIfNotExists "$env:ProgramFiles\nodejs"
Add-ToPathIfNotExists "$env:ProgramFiles\Git\cmd"

$localBinPath = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBinPath)) { New-Item -ItemType Directory -Path $localBinPath -Force | Out-Null }
Add-ToPathIfNotExists $localBinPath

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ============================================
# 4. Install Claude Code
# ============================================

Write-Host ""
Write-Host "Installing Claude Code..." -ForegroundColor Yellow

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Host "Claude Code already installed" -ForegroundColor Green
} else {
    try {
        & ([scriptblock]::Create((irm https://claude.ai/install.ps1))) latest
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Claude Code installed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Claude Code install failed. Try manually: https://claude.ai/install.ps1" -ForegroundColor Yellow
    }
}

# ============================================
# 5. Install VS Code extensions
# ============================================

Write-Host ""
Write-Host "Installing VS Code extensions..." -ForegroundColor Yellow

$codePath = $null
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) { $codePath = $codeCmd.Source }

if (-not $codePath) {
    $fallbacks = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($p in $fallbacks) {
        if (Test-Path $p) { $codePath = $p; break }
    }
}

if ($codePath) {
    $extensions = @(
        "saoudrizwan.claude-dev",     # Cline - AI coding assistant
        "ms-vscode-remote.remote-ssh" # Remote SSH
    )
    foreach ($ext in $extensions) {
        Write-Host "   Installing: $ext" -ForegroundColor Gray
        try {
            & $codePath --install-extension $ext --force 2>&1 | Out-Null
            Write-Host "   $ext - OK" -ForegroundColor Green
        } catch {
            Write-Host "   WARNING: Failed to install $ext" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "WARNING: VS Code not found, skipping extensions" -ForegroundColor Yellow
}

# ============================================
# 6. Configure Git
# ============================================

Write-Host ""
Write-Host "Configuring Git..." -ForegroundColor Yellow

$gitPath = $null
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) { $gitPath = $gitCmd.Source }
if (-not $gitPath) {
    $defaultGit = "$env:ProgramFiles\Git\cmd\git.exe"
    if (Test-Path $defaultGit) { $gitPath = $defaultGit }
}

if ($gitPath) {
    $gitconfigPath   = Join-Path $env:USERPROFILE ".gitconfig"
    $sourceGitconfig = Join-Path $RepoRoot "dotfiles\gitconfig"

    if (-not (Test-Path $gitconfigPath) -and (Test-Path $sourceGitconfig)) {
        Copy-Item $sourceGitconfig $gitconfigPath
        & $gitPath config --global core.autocrlf true
        Write-Host "Copied gitconfig template" -ForegroundColor Green
    } else {
        Write-Host ".gitconfig already exists" -ForegroundColor Green
    }

    $existingName  = & $gitPath config --global user.name  2>$null
    $existingEmail = & $gitPath config --global user.email 2>$null

    if ([string]::IsNullOrWhiteSpace($existingName) -or $existingName -eq "YOUR_NAME_HERE") {
        $gitName = Read-Host "Enter your Git username"
        if (-not [string]::IsNullOrWhiteSpace($gitName)) {
            & $gitPath config --global user.name "$gitName"
            Write-Host "Git user.name set: $gitName" -ForegroundColor Green
        }
    } else {
        Write-Host "Git user.name already set: $existingName" -ForegroundColor Gray
    }

    if ([string]::IsNullOrWhiteSpace($existingEmail) -or $existingEmail -eq "YOUR_EMAIL_HERE") {
        $gitEmail = Read-Host "Enter your Git email"
        if (-not [string]::IsNullOrWhiteSpace($gitEmail)) {
            & $gitPath config --global user.email "$gitEmail"
            Write-Host "Git user.email set: $gitEmail" -ForegroundColor Green
        }
    } else {
        Write-Host "Git user.email already set: $existingEmail" -ForegroundColor Gray
    }
} else {
    Write-Host "WARNING: Git not found, skipping Git config (run script again after reboot)" -ForegroundColor Yellow
}

# ============================================
# Done
# ============================================

Write-Host ""
if ($script:RebootRequired) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  RESTART REQUIRED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "After restarting, run this script again to install Docker Desktop." -ForegroundColor Yellow
} else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Setup complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installed versions:" -ForegroundColor Cyan
try { Write-Host "   Python: $(python --version 2>&1)" -ForegroundColor Gray } catch {}
try { Write-Host "   Node:   $(node --version 2>&1)" -ForegroundColor Gray } catch {}
try { Write-Host "   Git:    $(git --version 2>&1)" -ForegroundColor Gray } catch {}
try { Write-Host "   Docker: $(docker --version 2>&1)" -ForegroundColor Gray } catch { Write-Host "   Docker: not yet installed" -ForegroundColor Gray }
Write-Host ""
