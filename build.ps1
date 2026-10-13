# build.ps1 - Wrapper để build Packer template sạch

Write-Host "=== Cleaning up previous build artifacts ===" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

Write-Host "=== Start SSH key generation ===" -ForegroundColor Cyan

# 1. Resolve paths relative to this script
$projectRoot = $PSScriptRoot
$secretsDir  = Join-Path $projectRoot ".secrets"
$keyFile     = Join-Path $secretsDir "packer_build_key"
$publicKeyFile = "$keyFile.pub"

Write-Host "Project root: $projectRoot"
Write-Host "Secrets directory: $secretsDir"

# 2. Ensure the secrets directory exists
New-Item -ItemType Directory -Path $secretsDir -Force |
    Out-Null

# 3. Remove the previous key pair
Remove-Item -Path $keyFile, $publicKeyFile `
    -Force -ErrorAction SilentlyContinue

# 4. Generate a temporary Ed25519 key pair without a passphrase
& ssh-keygen -q -t ed25519 `
    -f $keyFile `
    -N '""' `
    -C "packer-build-temp"

if ($LASTEXITCODE -ne 0) {
    throw "SSH key generation failed."
}

# 5. Verify the generated files
if (-not (Test-Path $keyFile) -or
    -not (Test-Path $publicKeyFile)) {
    throw "SSH key pair was not generated correctly."
}

# 6. set the environment variable
$env:PACKER_PRIVATE_KEY_PATH = (Resolve-Path ".\.secrets\packer_build_key").Path
$env:PACKER_PUBLIC_KEY_PATH  = (Resolve-Path ".\.secrets\packer_build_key.pub").Path

$env:ROOT_HASHED_PASSWORD = (openssl passwd -6 -salt somesalt123 packer).Trim()


Write-Host "=== SSH key generation completed ===" -ForegroundColor Green
Write-Host "Private key: $keyFile"
Write-Host "Public key:  $publicKeyFile"


# Delete old template
if (Test-Path "template") {
    Remove-Item "template" -Recurse -Force
    Write-Host "Removed old template directory" -ForegroundColor Yellow
}

# Delete packer cache (nếu muốn build lại từ đầu)
if (Test-Path "packer_cache") {
    Remove-Item "packer_cache" -Recurse -Force
    Write-Host "Removed packer cache" -ForegroundColor Yellow
}

# Remove known_hosts entry cũ (tránh warning khi IP trùng)
$knownHosts = "$env:USERPROFILE\.ssh\known_hosts"
if (Test-Path $knownHosts) {
    # Xóa dòng chứa IP VMware NAT (192.168.40.x)
    (Get-Content $knownHosts) | Where-Object { $_ -notmatch '192\.168\.40\.' } | Set-Content $knownHosts
    Write-Host "Cleaned known_hosts entries" -ForegroundColor Yellow
}

Write-Host "`n=== Starting Packer build ===" -ForegroundColor Cyan
packer validate rocky.pkr.hcl
packer init rocky.pkr.hcl
packer build rocky.pkr.hcl

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Build successful! ===" -ForegroundColor Green
    Write-Host "Template ready at: ./template/" -ForegroundColor Green
} else {
    Write-Host "`n=== Build failed ===" -ForegroundColor Red
    exit $LASTEXITCODE
}