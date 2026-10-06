# build.ps1 - Wrapper để build Packer template sạch

Write-Host "=== Cleaning up previous build artifacts ===" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

$keyFile = "packer_build_key"

# 1. Xóa key cũ để tạo key mới mỗi lần build
if (Test-Path "$keyFile") { Remove-Item "$keyFile" -Force }
if (Test-Path "$keyFile.pub") { Remove-Item "$keyFile.pub" -Force }

# 2. Tạo cặp key mới (không passphrase)
Write-Host "Generating SSH key..." -ForegroundColor Cyan

# Dùng cmd.exe để xử lý "" đúng cách — PowerShell hay làm hỏng empty argument
$cmdLine = 'ssh-keygen -t ed25519 -f "{0}" -N "" -C "packer-build-temp"' -f $keyFile
cmd.exe /c $cmdLine

if ($LASTEXITCODE -ne 0) {
    Write-Host "ssh-keygen failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$keyFile.pub")) {
    Write-Host "Public key file was not generated: $keyFile.pub" -ForegroundColor Red
    exit 1
}

# 3. Đọc public key và mã hóa base64
$pubKey = (Get-Content "$keyFile.pub" -Raw).Trim()
$pubKeyB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubKey))
$env:PACKER_SSH_PUBLIC_KEY = $pubKeyB64

Write-Host "Public key (base64): $pubKeyB64" -ForegroundColor Green

# Xóa template cũ
if (Test-Path "template") {
    Remove-Item "template" -Recurse -Force
    Write-Host "Removed old template directory" -ForegroundColor Yellow
}

# Xóa packer cache (nếu muốn build lại từ đầu)
if (Test-Path "packer_cache") {
    Remove-Item "packer_cache" -Recurse -Force
    Write-Host "Removed packer cache" -ForegroundColor Yellow
}

# Xóa known_hosts entry cũ (tránh warning khi IP trùng)
$knownHosts = "$env:USERPROFILE\.ssh\known_hosts"
if (Test-Path $knownHosts) {
    # Xóa dòng chứa IP VMware NAT (192.168.40.x)
    (Get-Content $knownHosts) | Where-Object { $_ -notmatch '192\.168\.40\.' } | Set-Content $knownHosts
    Write-Host "Cleaned known_hosts entries" -ForegroundColor Yellow
}

Write-Host "`n=== Starting Packer build ===" -ForegroundColor Cyan
packer init rocky.pkr.hcl
packer build rocky.pkr.hcl

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Build successful! ===" -ForegroundColor Green
    Write-Host "Template ready at: ./template/" -ForegroundColor Green
} else {
    Write-Host "`n=== Build failed ===" -ForegroundColor Red
    exit $LASTEXITCODE
}