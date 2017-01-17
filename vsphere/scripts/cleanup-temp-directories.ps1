Get-ChildItem -Path C:\Windows\Temp |
    Select-Object -expandproperty fullname |
    Where { $_ -notlike "C:\Windows\Temp\vm*" } |
    Remove-Item -Force -Recurse

Remove-Item -Path C:\*.exe -Force
Remove-Item -Path C:\*.zip -Force
