
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')]
    [string]$Name
)

$ErrorActionPreference = "Stop"

# ---------- Configuration ----------
$LabRoot = "E:\linux-labs\packer-rocky"
$BaseVmx = Join-Path $LabRoot "template\rocky-base.vmx"
$AdminUser = "packer"
$SecretsDir = Join-Path $LabRoot ".secrets"
$PrivateKeyPath = Join-Path $SecretsDir "packer_build_key"
$PublicKeyPath = "$PrivateKeyPath.pub"
$TimeoutSeconds = 300

if (-not (Test-Path $BaseVmx -PathType Leaf)) {
    throw "Base VMX not found: $BaseVmx"
}
if (-not (Test-Path $PrivateKeyPath -PathType Leaf)) {
    throw "Private key not found: $PrivateKeyPath"
}
if (-not (Test-Path $PublicKeyPath -PathType Leaf)) {
    throw "Public key not found: $PublicKeyPath"
}

# ---------- Helpers ----------
function Find-Vmrun {
    $cmd = Get-Command vmrun.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:ProgramFiles (x86)\VMware\VMware Workstation\vmrun.exe",
        "$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }

    throw "Cannot find vmrun.exe. Add VMware Workstation to PATH or set its path in this script."
}

function ConvertTo-WslPath([string]$WindowsPath) {
    $result = & wsl.exe -e wslpath -a $WindowsPath
    if ($LASTEXITCODE -ne 0 -or -not $result) {
        throw "Could not convert path for WSL: $WindowsPath"
    }
    return ([string]$result).Trim()
}

function Escape-BashSingleQuote([string]$Value) {
    return "'" + $Value.Replace("'", "'\''") + "'"
}

function Set-VmxSeedIso([string]$VmxPath, [string]$IsoPath) {
    $content = Get-Content -LiteralPath $VmxPath -Raw

    # Replace any existing IDE secondary-device configuration.
    $content = [regex]::Replace(
        $content,
        '(?m)^ide1:0\..*\r?\n?',
        ''
    )

    $iso = $IsoPath.Replace('\', '\\')
    $deviceConfig = @"
ide1:0.present = "TRUE"
ide1:0.deviceType = "cdrom-image"
ide1:0.fileName = "$iso"
ide1:0.startConnected = "TRUE"
ide1:0.autodetect = "FALSE"
"@

    $content = $content.TrimEnd() + "`r`n" + $deviceConfig + "`r`n"
    Set-Content -LiteralPath $VmxPath -Value $content -Encoding ASCII
}

# ---------- Preflight ----------
$Vmrun = Find-Vmrun

if (-not (Test-Path $BaseVmx)) {
    throw "Base VMX not found: $BaseVmx"
}
if (-not (Test-Path $PublicKeyPath)) {
    throw "SSH public key not found: $PublicKeyPath"
}
if (-not (Test-Path $PrivateKeyPath)) {
    throw "SSH private key not found: $PrivateKeyPath"
}

# Ensure the template is powered off before cloning.
& $Vmrun list | Out-Null
$runningVms = & $Vmrun list
if ($runningVms -contains $BaseVmx) {
    throw "Base VM is running. Shut down rocky-base before cloning."
}

$CloneDir = Join-Path $LabRoot $Name
$CloneVmx = Join-Path $CloneDir "$Name.vmx"
$SeedDir = Join-Path $CloneDir "seed"
$SeedIso = Join-Path $CloneDir "seed.iso"

if (Test-Path $CloneDir) {
    throw "Clone directory already exists: $CloneDir. Choose a new name or inspect/remove the old clone first."
}

New-Item -ItemType Directory -Path $CloneDir -Force | Out-Null
New-Item -ItemType Directory -Path $SeedDir -Force | Out-Null

$PublicKey = (Get-Content -LiteralPath $PublicKeyPath -Raw).Trim()
if (-not $PublicKey.StartsWith("ssh-ed25519 ") -and
    -not $PublicKey.StartsWith("ssh-rsa ")) {
    throw "Unexpected public key format in $PublicKeyPath"
}

# ---------- Build NoCloud seed ----------
$InstanceId = "iid-$Name"

$MetaData = @"
instance-id: $InstanceId
local-hostname: $Name
"@

$UserData = @"
#cloud-config
hostname: $Name
preserve_hostname: false
manage_etc_hosts: true

users:
  - name: $AdminUser
    gecos: Lab System Administrator
    groups: [wheel]
    shell: /bin/bash
    lock_passwd: true
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - $PublicKey

ssh_pwauth: false
disable_root: true
ssh_deletekeys: true
ssh_genkeytypes:
  - ed25519
"@

Set-Content -LiteralPath (Join-Path $SeedDir "meta-data") -Value $MetaData -Encoding ASCII
Set-Content -LiteralPath (Join-Path $SeedDir "user-data") -Value $UserData -Encoding ASCII

# Create a NoCloud ISO using genisoimage installed inside WSL.
$SeedDirWsl = ConvertTo-WslPath $SeedDir
$SeedIsoWsl = ConvertTo-WslPath $SeedIso

$bashCommand = "genisoimage -quiet -output $(Escape-BashSingleQuote $SeedIsoWsl) -volid cidata -joliet -rock $(Escape-BashSingleQuote "$SeedDirWsl/user-data") $(Escape-BashSingleQuote "$SeedDirWsl/meta-data")"

& wsl.exe -e bash -lc $bashCommand
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $SeedIso)) {
    throw "Failed to create NoCloud seed ISO. Check that genisoimage is installed in WSL."
}

# ---------- Clone and attach seed ----------
Write-Host "Cloning $Name from base image..."

& $Vmrun clone $BaseVmx $CloneVmx full "-cloneName=$Name"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $CloneVmx)) {
    throw "vmrun clone failed. Inspect VMware output and the clone directory."
}

Set-VmxSeedIso -VmxPath $CloneVmx -IsoPath $SeedIso

# ---------- Boot clone ----------
Write-Host "Starting $Name..."
& $Vmrun start $CloneVmx nogui
if ($LASTEXITCODE -ne 0) {
    throw "Could not start $Name. The clone has been kept for troubleshooting."
}

# ---------- Discover guest IP ----------
Write-Host "Waiting for VMware Tools to report the guest IP..."
$GuestIp = $null
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

do {
    Start-Sleep -Seconds 5
    $ipOutput = & $Vmrun getGuestIPAddress $CloneVmx -wait -timeout $TimeoutSeconds 2>$null
    if ($LASTEXITCODE -eq 0 -and $ipOutput) {
        $candidate = ([string]$ipOutput).Trim()
        if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$' -and $candidate -ne "127.0.0.1") {
            $GuestIp = $candidate
        }
    }
} while (-not $GuestIp -and (Get-Date) -lt $deadline)

if (-not $GuestIp) {
    throw "No guest IPv4 address found. Check VMware Tools, DHCP, and the VM console."
}

Write-Host "Guest IP: $GuestIp"

# ---------- Wait for SSH ----------
$KnownHostsFile = Join-Path $CloneDir "known_hosts"
$SshOptions = @(
    "-i", $PrivateKeyPath,
    "-o", "IdentitiesOnly=yes",
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=5",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "UserKnownHostsFile=$KnownHostsFile"
)

Write-Host "Waiting for SSH and cloud-init..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$sshReady = $false

do {
    & ssh.exe @SshOptions "$AdminUser@$GuestIp" "sudo -n cloud-init status --wait"
    if ($LASTEXITCODE -eq 0) {
        $sshReady = $true
        break
    }
    Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)

if (-not $sshReady) {
    throw "SSH/cloud-init did not become ready. The clone is kept for troubleshooting."
}

# ---------- Verify identity ----------
$RemoteCheck = "printf 'hostname='; hostnamectl --static; printf 'user='; id -un; printf 'cloud-init='; cloud-init status --long | head -n 1; printf 'machine-id='; cat /etc/machine-id"

& ssh.exe @SshOptions "$AdminUser@$GuestIp" $RemoteCheck
if ($LASTEXITCODE -ne 0) {
    throw "Remote verification failed. The clone is kept for troubleshooting."
}

Write-Host ""
Write-Host "Clone is ready:"
Write-Host "  Name: $Name"
Write-Host "  IP:   $GuestIp"
Write-Host "  User: $AdminUser"
Write-Host "  SSH:  ssh -i `"$PrivateKeyPath`" $AdminUser@$GuestIp"
