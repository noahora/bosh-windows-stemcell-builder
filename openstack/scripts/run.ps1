# This will simply be a script to MANUALLY setup the agent.
# It is not fully implemented.

# $ErrorActionPreference = "Stop";
# trap { $host.SetShouldExit(1) }

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)

    Remove-Item -Path $zipfile -Force
}

function setup-acl {

    param([string]$folder,[bool]$disableInheritance=$True)

    cacls.exe $folder /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with $LASTEXITCODE"
    }

    cacls.exe $folder /T /E /R "BUILTIN\IIS_IUSRS"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with $LASTEXITCODE"
    }

    cacls.exe $folder /T /E /G Administrator:F
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with $LASTEXITCODE"
    }

    if ($disableInheritance) {
      $acl = Get-ACL -Path $folder
      $acl.SetAccessRuleProtection($True, $True)
      Set-Acl -Path $folder -AclObject $acl
    }
}

# Add utilities to current path.
$env:PATH="${env:PATH};C:\var\vcap\bosh\bin"

# Add utilities to system path (does not apply to current shell).
Setx $env:PATH "${env:PATH};C:\var\vcap\bosh\bin" /m

New-Item -Path "C:\bosh" -ItemType "directory" -Force
# Remove permissions for C:\bosh directories.
setup-acl "C:\bosh"

New-Item -Path "C:\var\vcap\bosh\bin" -ItemType "directory" -Force
New-Item -Path "C:\var\vcap\bosh\log" -ItemType "directory" -Force
# Remove permissions for C:\var
setup-acl "C:\var"

# Copy deps
$DepsDir = "${env:TEMP}\deps"
New-Item -Path "${DepsDir}" -ItemType "directory" -Force
Unzip "C:\Users\Administrator\deps.zip" "${DepsDir}"

# C:\bosh
$boshRoot=@(
    "bosh-agent.exe",
    "pipe.exe",
    "service_wrapper.exe",
    "service_wrapper.xml"
)
foreach ($name in $boshRoot) {
    Move-Item "${DepsDir}\${name}" "C:\bosh\${name}"
}

Copy-Item "C:\bosh\service_wrapper.exe" "C:\var\vcap\bosh\bin\service_wrapper.exe"

# C:\var\vcap\bosh\bin
$boshBin=(
    "bosh-blobstore-dav.exe",
    "bosh-blobstore-s3.exe",
    "job-service-wrapper.exe",
    "tar.exe",
    "zlib1.dll"
)
foreach ($name in $boshBin) {
    Move-Item "${DepsDir}\${name}" "C:\var\vcap\bosh\bin\${name}"
}

New-Item -ItemType "file" -path "C:\bosh\agent.json" -Value @"
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "virtio"
    }
  },
  "Infrastructure": {
    "Settings": {
      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254",
          "UserDataPath": "/latest/user-data",
          "InstanceIDPath": "/latest/meta-data/instance-id",
          "SSHKeysPath": "/latest/meta-data/public-keys/0/openssh-key"
        },
        {
          "Type": "File",
          "SettingsPath": "/var/vcap/bosh/agent-bootstrap-env.json"
        },
        {
          "Type": "ConfigDrive",
          "DiskPaths": [
            "/dev/disk/by-label/CONFIG-2",
            "/dev/disk/by-label/config-2"
          ],
          "MetaDataPath": "ec2/latest/meta-data.json",
          "UserDataPath": "ec2/latest/user-data"
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
"@

$OldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
$AddedFolder='C:\var\vcap\bosh\bin'
$NewPath=$OldPath+';'+$AddedFolder
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath

C:\bosh\service_wrapper.exe install
if ($LASTEXITCODE -ne 0) {
  Write-Error "Error installing BOSH service wrapper"
}

# TODO (CEV): Need to test with OpenStack and CloudInit
# before re-enabling.
#
# Remove permissions for C:\windows\panther directories.
# setup-acl "C:\Windows\Panther" $false

# Setup winrm

# Set Execution Policy 64 Bit
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
"Set Execution Policy 64 Bit (Exit Code: ${LASTEXITCODE})"

# Set Execution Policy 32 Bit
C:\Windows\SysWOW64\cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"
"Set Execution Policy 32 Bit (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -q
cmd.exe /c 'winrm quickconfig -q'
"winrm quickconfig -q (Exit Code: ${LASTEXITCODE})"

# winrm quickconfig -transport:http
cmd.exe /c 'winrm quickconfig -transport:http'
"winrm quickconfig -transport:http (Exit Code: ${LASTEXITCODE})"

# Win RM MaxTimoutms
cmd.exe /c 'winrm set winrm/config @{MaxTimeoutms="1800000"}'
"Win RM MaxTimoutms (Exit Code: ${LASTEXITCODE})"

# Win RM MaxMemoryPerShellMB
cmd.exe /c 'winrm set winrm/config/winrs @{MaxMemoryPerShellMB="800"}'
"Win RM MaxMemoryPerShellMB (Exit Code: ${LASTEXITCODE})"

# Win RM AllowUnencrypted
cmd.exe /c 'winrm set winrm/config/service @{AllowUnencrypted="true"}'
"Win RM AllowUnencrypted (Exit Code: ${LASTEXITCODE})"

# Win RM auth Basic
cmd.exe /c 'winrm set winrm/config/service/auth @{Basic="true"}'
"Win RM auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM client auth Basic
cmd.exe /c 'winrm set winrm/config/client/auth @{Basic="true"}'
"Win RM client auth Basic (Exit Code: ${LASTEXITCODE})"

# Win RM listener Address/Port
cmd.exe /c 'winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"}'
"Win RM listener Address/Port (Exit Code: ${LASTEXITCODE})"

# Win RM adv firewall enable
cmd.exe /c 'netsh advfirewall firewall set rule group="remote administration" new enable=yes'
"Win RM adv firewall enable (Exit Code: ${LASTEXITCODE})"

# Win RM port open
cmd.exe /c 'netsh firewall add portopening TCP 5985 "Port 5985"'
"Win RM port open (Exit Code: ${LASTEXITCODE})"

# Stop Win RM Service
cmd.exe /c 'net stop winrm'
"Stop Win RM Service (Exit Code: ${LASTEXITCODE})"

# Show file extensions in Explorer
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f'
"Show file extensions in Explorer"

# Enable QuickEdit mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\Console /v QuickEdit /t REG_DWORD /d 1 /f'
"Enable QuickEdit mode"

# Show Run command in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f'
"Show Run command in Start Menu"

# Show Administrative Tools in Start Menu
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f'
"Show Administrative Tools in Start Menu"

# Zero Hibernation File
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateFileSizePercent /t REG_DWORD /d 0 /f'
"Zero Hibernation File"

# Disable Hibernation Mode
cmd.exe /c '%SystemRoot%\System32\reg.exe ADD HKLM\SYSTEM\CurrentControlSet\Control\Power\ /v HibernateEnabled /t REG_DWORD /d 0 /f'
"Disable Hibernation Mode"

# Disable password expiration for Administrator user
cmd.exe /c 'wmic useraccount where "name=''Administrator''" set PasswordExpires=FALSE'
"Disable password expiration for Administrator user (Exit Code: ${LASTEXITCODE})"

# Win RM Autostart
cmd.exe /c 'sc config winrm start=auto'
"Win RM Autostart (Exit Code: ${LASTEXITCODE})"

# Start Win RM Service
cmd.exe /c 'net start winrm'
"Start Win RM Service (Exit Code: ${LASTEXITCODE})"

# Allow Inbound and Outbound
set-netfirewallprofile -all -DefaultInboundAction Allow -DefaultOutboundAction Allow
"Open firewall for inbound and outbound (Exit Code: ${LASTEXITCODE})"
