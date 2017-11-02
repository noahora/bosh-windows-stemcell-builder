<#
.Synopsis
    Install Windows 2012 CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell on Windows 2012R2
#>
function Install-CFFeatures2012 {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Installing CloudFoundry Cell Windows 2012 Features"
  $ErrorActionPreference = "Stop";
  trap { $host.SetShouldExit(1) }

  WindowsFeatureInstall("Web-Webserver")
  WindowsFeatureInstall("Web-WebSockets")
  WindowsFeatureInstall("AS-Web-Support")
  WindowsFeatureInstall("AS-NET-Framework")
  WindowsFeatureInstall("Web-WHC")
  WindowsFeatureInstall("Web-ASP")

  Write-Log "Installed CloudFoundry Cell Windows 2012 Features"
}

<#
.Synopsis
    Install Windows 2016 CloudFoundry Cell components
.Description
    This cmdlet installs the minimum set of features for a CloudFoundry Cell on Windows 2016
#>
function Install-CFFeatures2016 {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Installing CloudFoundry Cell Windows 2016 Features"
  $ErrorActionPreference = "Stop";
  trap { $host.SetShouldExit(1) }

  WindowsFeatureInstall("FS-Resource-Manager")
  WindowsFeatureInstall("Containers")
  Remove-WindowsFeature Windows-Defender-Features

  Write-Log "Installed CloudFoundry Cell Windows 2016 Features"

  Write-Log "Setting WinRM startup type to automatic"
  Get-Service | Where-Object {$_.Name -eq "WinRM" } | Set-Service -StartupType Automatic
  shutdown /r /c "packer restart" /t 5
  net stop winrm
}

function Wait-ForNewIfaces() {
    param([string]$ifaces)
    $max = 20
    $try = 0

    while($try -le $max) {
        # Get a list of network interfaces created by installing Docker.
        $newIfaces=(Get-NetIPInterface -AddressFamily IPv4 | where {
        -Not ($_.InterfaceAlias -in $ifaces) -and $_.NlMtu -eq 1500
        }).InterfaceAlias

        if($newIfaces.Count -gt 0) {
            Write-Host "Docker added interfaces: $newIfaces"
            return $newIfaces
        }
        Start-Sleep -s 5
        $try++
    }

    Write-Error "Time-out waiting for docker to add Network Interface on GCP"
    Throw "Should not get here"
}

function Protect-CFCell {
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"
  enable-rdp
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"
  disable-service("WinRM")
  disable-service("W3Svc")
  set-firewall
  Write-Log "Getting WinRM config"
  $winrm_config = & cmd.exe /c 'winrm get winrm/config'
  Write-Log "$winrm_config"

  Write-Log "Disabling NetBIOS over TCP"
  Disable-NetBIOS
}

function WindowsFeatureInstall {
  param ([string]$feature)

  Write-Log "Installing $feature"
  If (!(Get-WindowsFeature $feature).Installed) {
    Install-WindowsFeature $feature
    If (!(Get-WindowsFeature $feature).Installed) {
      Throw "Failed to install $feature"
    }
  }
}

function enable-rdp {
  Write-Log "Starting to enable RDP"
  Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
  Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
  Write-Log "Enabled RDP"
}

function disable-service {
  Param([string]$Service)

  Write-Log "Starting to disable $Service"
  Get-Service | Where-Object {$_.Name -eq $Service } | Set-Service -StartupType Disabled
  Write-Log "Disabled $Service"
}

function set-firewall {
  Write-Log "Starting to set firewall rules"
	Set-NetFirewallProfile -all -DefaultInboundAction Block -DefaultOutboundAction Allow -AllowUnicastResponseToMulticast False -Enabled True
	check-firewall "public"
	check-firewall "private"
	check-firewall "domain"
  Write-Log "Finished setting firewall rules"
}

function get-firewall {
  param([string] $profile)

  $firewall = (Get-NetFirewallProfile -Name $profile)
  $result = "{0},{1},{2}" -f $profile,$firewall.DefaultInboundAction,$firewall.DefaultOutboundAction
  return $result

}

function exec
{
    param
    (
        [string] $ScriptBlock,
        [string] $StderrPrefix = "",
        [int[]] $AllowedExitCodes = @(0)
    )

    $backupErrorActionPreference = $script:ErrorActionPreference

    $script:ErrorActionPreference = "Continue"
    try
    {
        cmd /c $ScriptBlock 2`>`&1 | ForEach-Object -Process `
            {
                if ($_ -is [System.Management.Automation.ErrorRecord])
                {
                    "$StderrPrefix$_"
                }
                else
                {
                    "$_"
                }
            }
        if ($AllowedExitCodes -notcontains $LASTEXITCODE)
        {
            throw "Execution failed with exit code $LASTEXITCODE"
        }
    }
    finally
    {
        $script:ErrorActionPreference = $backupErrorActionPreference
    }
}

function check-firewall {
  param([string] $profile)

  $firewall = (get-firewall $profile)
  Write-Log $firewall
  if ($firewall -ne "$profile,Block,Allow") {
    Write-Log $firewall
    Throw "Unable to set $profile Profile"
  }
}

<#
.Synopsis
    Disables NetBIOS over TCP
.Description
    This cmdlet disables NetBIOS over TCP by configuring the network interfaces
    and by disabling all associated firewall rules.  Additionally, the ports
    used by NetBIOS over TCP are explicitly blocked.
#>
function Disable-NetBIOS {
  "Disabling NADA NetBios"
  [int]$counter=0
  while($counter -lt 10000) {
    $counter | Out-File -Append "/log.txt"
    "counter is $counter"
    $counter=$counter+1
  }
}
