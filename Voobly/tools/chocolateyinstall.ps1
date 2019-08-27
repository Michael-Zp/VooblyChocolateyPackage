$ErrorActionPreference = 'Stop'; 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

$fileLocation = "$toolsDir/install.exe"

$trialCount = 5

$swEu = New-Object System.Diagnostics.Stopwatch;
$swUs = New-Object System.Diagnostics.Stopwatch;

for ($i = 0; $i -lt $trialCount; $i++) {
	$swEu.Start()
	Get-WebHeaders -Url $urlEu *>$null
	$swEu.Stop()

	$swUs.Start()
	Get-WebHeaders -Url $urlUs *>$null
	$swUs.Stop()
}

$chosenServer = "EU"
$url = $urlEu

if($swEu.ElapsedMilliseconds -ge $swUs.ElapsedMilliseconds)
{
	$chosenServer = "US"
	$url = $urlUs
}

Write-Host "Connection to the $chosenServer servers seems faster. Starting download from the $chosenServer servers."

Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $fileLocation -Url $url

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  file          = $fileLocation

  softwareName  = 'Voobly*'

  checksum      = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType  = 'sha256'

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

Remove-Item $fileLocation -ErrorAction SilentlyContinue