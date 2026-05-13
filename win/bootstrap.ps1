# ============================================
# Tendo's Windows Dev Setup - Bootstrap
# 用管理员身份在 PowerShell 里跑这个就行
# ============================================

# 1. 装 Git
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements

# 2. 刷新 PATH，让 git 可以用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 3. 切换到用户目录，clone 或更新 repo
Set-Location $env:USERPROFILE
if (Test-Path "Setup\.git") {
    Write-Host "Updating existing repo..." -ForegroundColor Yellow
    git -C "$env:USERPROFILE\Setup" pull
} else {
    git clone https://github.com/Tendo9001/Setup.git
}

# 4. 进去跑 setup
Set-Location "$env:USERPROFILE\Setup\win"
powershell -ExecutionPolicy Bypass -File .\setup.ps1
