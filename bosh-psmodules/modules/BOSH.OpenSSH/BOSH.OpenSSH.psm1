<#
.Synopsis
    Install OpenSSH
.Description
    This cmdlet installs the OpenSSH on Windows
#>

function Install-OpenSSH {
      Write-Log "Starting to install OpenSSH"
      $tempDir = (New-TempDir)
      $file = (Join-Path $tempDir "openssh.zip")
      Download-OpenSSH -Destination $file
      # $contents = (Join-Path $tempDir "openssh")
      # Open-Zip -ZipFile $file -OutPath $contents
      # $dest = "C:\Program Files\OpenSSH"
      # Move-Item -Force -Path (Join-Path $contents "OpenSSH-Win64") -Destination $dest
      # . (Join-Path $dest "install-sshd.ps1")
      #  Set-Services to disabled
      Write-Log "Finished installing OpenSSH"
}

function Download-OpenSSH {
    Param(
        [string]$Destination = $(Throw "Provide the destination"),
        [string]$version = "v0.0.12.0"
    )
    $shas = @{
       "v0.0.12.0" = "e336c49fa1309f9b2fb325f268a7ef158ce11f15a3b030c0e3c3e926543900cd"
    }
    $uri = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/{0}/OpenSSH-Win64.zip" -f $version
    Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $Destination
    $sha256sum = (Get-FileHash $Destination).Hash
    if ($sha256sum -ne $shas[$version]){
       $msg="Version {0} sha256 is {1}, but expected {2}" -f $version,$sha256sum,$shas[$version]
       Write-Error $msg
    }
}

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}
