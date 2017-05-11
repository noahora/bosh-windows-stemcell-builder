Remove-Module -Name BOSH.OpenSSH -ErrorAction Ignore
Import-Module ./BOSH.OpenSSH.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Download-OpenSSH" {
    BeforeEach {
        $tempDir=(New-TempDir)
    }

    AfterEach {
        Remove-Item -Recurse -Force $tempDir
    }
    It "Downloads the correct version" {
        $file = (Join-Path $tempDir "openssh.zip")
        Download-OpenSSH -Destination $file
        Test-Path $file | Should be $True
    }
}

Remove-Module -Name BOSH.OpenSSH -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
