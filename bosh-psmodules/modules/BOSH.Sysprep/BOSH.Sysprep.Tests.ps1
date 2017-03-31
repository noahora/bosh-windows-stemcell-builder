Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Import-Module ./BOSH.Sysprep.psm1

Remove-Module -Name BOSH.Utils -ErrorAction Ignore
Import-Module ../BOSH.Utils/BOSH.Utils.psm1

function New-TempDir {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    (New-Item -ItemType Directory -Path (Join-Path $parent $name)).FullName
}

Describe "Enable-LocalSecurityPolicy" {
    BeforeEach {
        $PolicyDestination=(New-TempDir)
    }

    AfterEach {
        Remove-Item -Recurse -Force $PolicyDestination
    }

    It "places the policy files in the destination and runs lgpo.exe" {
        $lgpoExe = "cmd.exe /c 'echo hello'"
        { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Not Throw
        (Test-Path (Join-Path $PolicyDestination "policy-baseline")) | Should Be $True
        (Join-Path $PolicyDestination "lgpo.log") | Should Contain "hello"
    }

    Context "when lgpo.exe fails" {
        It "throws" {
            $lgpoExe = "cmd.exe /c 'exit 1'"
            { Enable-LocalSecurityPolicy -LgpoExe $lgpoExe -PolicyDestination $PolicyDestination } | Should Throw "lgpo.exe exited with 1"
        }
    }
}

Describe "Create-Unattend" {
    BeforeEach {
        $UnattendDestination="." #(New-TempDir)
        $NewPassword="NewPassword"
        $ProductKey= "ProductKey"
        $Organization="Organization"
        $Owner="Owner"
        {
            Create-Unattend -UnattendDestination $UnattendDestination `
                -NewPassword $NewPassword `
                -ProductKey $ProductKey `
                -Organization $Organization `
                -Owner $Owner
        } | Should Not Throw
    }

    AfterEach {
        #Remove-Item -Recurse -Force $UnattendDestination
    }

    It "places the generated Unattend file in the specified directory" {
        Test-Path (Join-Path $UnattendDestination "unattend.xml") | Should Be $True
    }

    Context "the generated Unattend file" {
        BeforeEach {
            $FullPath = (Join-Path $UnattendDestination "unattend.xml")
            [xml]$unattendXML = Get-Content -Path $FullPath
        }

        It "is valid xml" {}

        It "contains a New Password" {
            $expected = $NewPassword
            Write-Host $unattendXML.unattend.ToString().Count
            Write-Host "BYE"
            $unattendXML.unattend.settings.component.UserAccounts.AdministratorPassword.Value | Should Be $expected
        }

        It "Product Key" {
            $expected= $ProductKey
            Write-Host $unattendXML.unattend.settings.component.ProductKey.InnerXML
            #$unattendXML.unattend.settings.component.ProductKey | Should Be $expected
        }

        It "Organization" {
            $expected= $Organization
            { $unattendXML.unattend.settings.component.RegisteredOrganization } | Should Be $expected
        }

        It "Owner" {
            $expected= $Owner
            $unattendXML.unattend.settings.component.RegisteredOwner | Should Be $expected
        }
    }
}

Remove-Module -Name BOSH.Sysprep -ErrorAction Ignore
Remove-Module -Name BOSH.Utils -ErrorAction Ignore
