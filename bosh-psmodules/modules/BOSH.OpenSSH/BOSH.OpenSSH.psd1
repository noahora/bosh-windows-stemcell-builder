@{
RootModule = 'BOSH.OpenSSH'
ModuleVersion = '0.1'
GUID = 'e87bc371-4a87-483d-bb6b-8c45d8047578'
Author = 'BOSH'
Copyright = '(c) 2017 BOSH'
Description = 'Installl and Configure OpenSSH on Windows'
PowerShellVersion = '4.0'
RequiredModules = @('BOSH.Utils')
FunctionsToExport = @('Install-OpenSSH')
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @()
PrivateData = @{
    PSData = @{
        Tags = @('BOSH')
        LicenseUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder/blob/master/LICENSE'
        ProjectUri = 'https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder'
    }
}
}
