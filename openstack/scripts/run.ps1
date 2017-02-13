# This will simply be a script to MANUALLY setup the agent.
# It is not fully implemented.

$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

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
    "zlib1.dll",
    "pipe.exe"
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

# install redhat drivers for openstack
Mount-DiskImage -ImagePath ${DepsDir}\virtio-win-0.1.126.iso
New-Item -ItemType "file" -path "${DepsDir}\redhat.cert.cer" -Value @"
-----BEGIN CERTIFICATE-----
MIIFBjCCA+6gAwIBAgIQVsbSZ63gf3LutGA7v4TOpTANBgkqhkiG9w0BAQUFADCB
tDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug
YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykxMDEuMCwGA1UEAxMl
VmVyaVNpZ24gQ2xhc3MgMyBDb2RlIFNpZ25pbmcgMjAxMCBDQTAeFw0xNjAzMTgw
MDAwMDBaFw0xODEyMjkyMzU5NTlaMGgxCzAJBgNVBAYTAlVTMRcwFQYDVQQIEw5O
b3J0aCBDYXJvbGluYTEQMA4GA1UEBxMHUmFsZWlnaDEWMBQGA1UEChQNUmVkIEhh
dCwgSW5jLjEWMBQGA1UEAxQNUmVkIEhhdCwgSW5jLjCCASIwDQYJKoZIhvcNAQEB
BQADggEPADCCAQoCggEBAMA3SYpIcNIEzqqy1PNimjt3bVY1KuIuvDABkx8hKUG6
rl9WDZ7ibcW6f3cKgr1bKOAeOsMSDu6i/FzB7Csd9u/a/YkASAIIw48q9iD4K6lb
Kvd+26eJCUVyLHcWlzVkqIEFcvCrvaqaU/YlX/antLWyHGbtOtSdN3FfY5pvvTbW
xf8PJBWGO3nV9CVL1DMK3wSn3bRNbkTLttdIUYdgiX+q8QjbM/VyGz7nA9UvGO0n
FWTZRdoiKWI7HA0Wm7TjW3GSxwDgoFb2BZYDDNSlfzQpZmvnKth/fQzNDwumhDw7
tVicu/Y8E7BLhGwxFEaP0xZtENTpn+1f0TxPxpzL2zMCAwEAAaOCAV0wggFZMAkG
A1UdEwQCMAAwDgYDVR0PAQH/BAQDAgeAMCsGA1UdHwQkMCIwIKAeoByGGmh0dHA6
Ly9zZi5zeW1jYi5jb20vc2YuY3JsMGEGA1UdIARaMFgwVgYGZ4EMAQQBMEwwIwYI
KwYBBQUHAgEWF2h0dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUFBwICMBkM
F2h0dHBzOi8vZC5zeW1jYi5jb20vcnBhMBMGA1UdJQQMMAoGCCsGAQUFBwMDMFcG
CCsGAQUFBwEBBEswSTAfBggrBgEFBQcwAYYTaHR0cDovL3NmLnN5bWNkLmNvbTAm
BggrBgEFBQcwAoYaaHR0cDovL3NmLnN5bWNiLmNvbS9zZi5jcnQwHwYDVR0jBBgw
FoAUz5mp6nsm9EvJjo/X8AUm7+PSp50wHQYDVR0OBBYEFL/39F5yNDVDib3B3Uk3
I8XJSrxaMA0GCSqGSIb3DQEBBQUAA4IBAQDWtaW0Dar82t1AdSalPEXshygnvh87
Rce6PnM2/6j/ijo2DqwdlJBNjIOU4kxTFp8jEq8oM5Td48p03eCNsE23xrZl5qim
xguIfHqeiBaLeQmxZavTHPNM667lQWPAfTGXHJb3RTT4siowcmGhxwJ3NGP0gNKC
PHW09x3CdMNCIBfYw07cc6h9+Vm2Ysm9MhqnVhvROj+AahuhvfT9K0MJd3IcEpjX
Z7aMX78Vt9/vrAIUR8EJ54YGgQsF/G9Adzs6fsfEw5Nrk8R0pueRMHRTMSroTe0V
Ae2nvuUU6rVI30q8+UjQCxu/ji1/JnitNkUyOPyC46zL+kfHYSnld8U1
-----END CERTIFICATE-----
"@
certutil -addstore TrustedPublisher "${DepsDir}\redhat.cert.cer"
pnputil -i -a E:\viostor\2k12R2\amd64\viostor.inf
pnputil -i -a E:\NetKVM\2k12R2\amd64\netkvm.inf

# install cloudbase init
Start-Process -Wait -FilePath msiexec -ArgumentList "/i  ${DepsDir}\CloudbaseInitSetup_0_9_9_x64.msi /qn /l*v C:\log.txt USERNAME=Administrator"

# overwrite unattend.xml for cloudbase to change administrator password

New-Item -ItemType "file" -path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\setup-admin.ps1" -Value @'
$NewPassword = "Password123!"
$AdminUser = [ADSI]"WinNT://${env:computername}/Administrator,User"
$AdminUser.SetPassword($NewPassword)
$AdminUser.passwordExpired = 0
$AdminUser.setinfo()
'@

New-Item -ItemType "file" -path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml" -Force -Value @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="generalize">
    <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>1</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\Python\Scripts\cloudbase-init.exe" --config-file "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf"</Path>
          <Description>Run Cloudbase-Init to set the hostname</Description>
          <WillReboot>Never</WillReboot>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Path>C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\setup-admin.ps1"</Path>
          <Description>password</Description>
          <WillReboot>Always</WillReboot>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
"@

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

# final sysprep

C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /quiet /shutdown /unattend:'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
