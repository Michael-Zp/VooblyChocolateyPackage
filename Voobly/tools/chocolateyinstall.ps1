$ErrorActionPreference = 'Stop'; 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

$fileLocation = "$toolsDir/install.exe"

$trialCount = 3

$swEu = New-Object System.Diagnostics.Stopwatch;
$swUs = New-Object System.Diagnostics.Stopwatch;

$timeEu = 0
$successfullRequestsEu = 0
$timeUs = 0
$successfullRequestsUs = 0

for ($i = 0; $i -lt $trialCount; $i++) {
	$swEu.Restart()
	try
	{
		Get-WebHeaders -Url $urlEu | Out-Null
		$timeEu += $swEu.ElapsedMilliseconds
		$successfullRequestsEu += 1
	}
	catch
	{ }
	$swEu.Stop()

	$swUs.Restart()
	try
	{
		Get-WebHeaders -Url $urlUs | Out-Null
		$timeUs += $swUs.ElapsedMilliseconds
		$successfullRequestsUs += 1
	}
	catch
	{ }
	$swUs.Stop()
}


if($successfullRequestsEu -gt 0)
{
	$avgTimeEu = $timeEu / $successfullRequestsEu
}

if($successfullRequestsUs -gt 0)
{
	$avgTimeUs = $timeUs / $successfullRequestsUs
}

if($successfullRequestsEu -eq 0 -and $successfullRequestsUs -eq 0)
{
	Write-Host "Could not connect to download server. Aborting."
	return -1;
}

$chosenServer = "EU"
$url = $urlEu

if($avgTimeEu -ge $avgTimeUs)
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