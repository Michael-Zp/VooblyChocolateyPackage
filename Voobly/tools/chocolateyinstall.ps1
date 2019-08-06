$ErrorActionPreference = 'Stop'; 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

$fileLocation = "$toolsDir/install.exe"
$fileLocationEu = "$toolsDir/installEu.exe"
$fileLocationUs = "$toolsDir/installUs.exe"

$sb = {
    Param($pn, $fl, $url, $url64, $modulePaths, $tempFile)
    $modulePaths | Import-Module
    Write-Host $pn $fl $url $url64

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Get-ChocolateyWebFile $pn $fl $url $url64
}

$modulePaths = Get-Module -All | Select-Object -ExpandProperty Path

Write-Host $modulePaths

$tempFile = [System.IO.Path]::GetTempFileName()
$jobEu = Start-Job -ScriptBlock $sb -ArgumentList $packageName, $fileLocationEu, $urlEu, $urlEu, $modulePaths, $tempFile
$jobUs = Start-Job -ScriptBlock $sb -ArgumentList $packageName, $fileLocationUs, $urlUs, $urlUs, $modulePaths, $tempFile

while((Get-Job -Id $jobEu.Id).State -eq "Running" -and (Get-Job -Id $jobUs.Id).State -eq "Running" )
{
    Start-Sleep -Milliseconds 50
}

if((Get-Job -Id $jobEu.Id).State -eq "Completed")
{
    Move-Item $fileLocationEu $fileLocation
}
else 
{
    Move-Item $fileLocationUs $fileLocation
}

Stop-Job -Id $jobEu.Id
Stop-Job -Id $jobUs.Id

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE_MSI_OR_MSU'
  file          = $fileLocation

  softwareName  = 'Voobly*'

  checksum      = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType  = 'sha256'
  checksum64    = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType64= 'sha256'

  silentArgs   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}

Install-ChocolateyPackage @packageArgs 

for ($i = 0; $i -lt 100; $i++) {
    Start-Sleep -Milliseconds 100
    $proc = Get-Process | Where-Object { $_.Name -eq 'voobly' }
    if($null -ne $proc)
    {
        Stop-Process $proc
        break
    }
}

Remove-Item $fileLocationEu -ErrorAction SilentlyContinue
Remove-Item $fileLocationUs -ErrorAction SilentlyContinue
Remove-Item $fileLocation -ErrorAction SilentlyContinue