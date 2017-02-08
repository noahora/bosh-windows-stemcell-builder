$ErrorActionPreference = "Stop";
trap { $host.SetShouldExit(1) }

function setup-acl {

    param([string]$folder)

    cacls.exe $folder /T /E /R "BUILTIN\Users"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with {0}" -f $LASTEXITCODE
    }
    cacls.exe $folder /T /E /G Administrator:F
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setting ACL for $folder exited with {0}" -f $LASTEXITCODE
    }
}

New-Item -Path "C:\var\vcap" -ItemType "directory" -Force

New-Item -Path "C:\bosh" -ItemType "directory" -Force
setup-acl "C:\bosh"

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
