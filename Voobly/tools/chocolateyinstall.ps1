$ErrorActionPreference = 'Stop'; 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

$fileLocation = "$toolsDir/install.exe"
$fileLocationEu = "$toolsDir/installEu.exe"
$fileLocationUs = "$toolsDir/installUs.exe"

$modulePaths = Get-Module -All | Select-Object -ExpandProperty Path

$jobCodeMeasure = 
{
    Param($pn, $fl, $url, $modulePaths, $securityProtocolTypes)

    $jobCodeDownload = {
		Param($pn, $fl, $url, $modulePaths, $securityProtocolTypes)
		$modulePaths | Import-Module
	
		[System.Net.ServicePointManager]::SecurityProtocol = $securityProtocolTypes
		Write-Output "StartedDownload"
		Get-ChocolateyWebFile -PackageName $pn -FileFullPath $fl -Url $url
	}
	  


	$downloadJob = Start-Job -ScriptBlock $jobCodeDownload -ArgumentList $pn, $fl, $url, $modulePaths, $securityProtocolTypes

    while ($true) 
    {
		Start-Sleep -Milliseconds 100

        if((Receive-Job -Id $downloadJob.Id) -eq "StartedDownload")
        {
			while(-not (Test-Path $fl))
			{
				Start-Sleep -Milliseconds 50
			}

			Start-Sleep -Seconds 1

			Stop-Job -Id $downloadJob.Id
			Write-Output "DownloadSuccess"
			return
        }
    }
}

Write-Host "Testing download speed to US and EU servers. The faster connection will be used to download the installer."

$securityProtocolTypes = [System.Net.ServicePointManager]::SecurityProtocol

$downloadJobEu = Start-Job -ScriptBlock $jobCodeMeasure -ArgumentList $packageName, $fileLocationEu, $urlEu, $modulePaths, $securityProtocolTypes
$downloadJobUs = Start-Job -ScriptBlock $jobCodeMeasure -ArgumentList $packageName, $fileLocationUs, $urlUs, $modulePaths, $securityProtocolTypes

$jobsCompleted = 0
$downloadEuSuccess = $downloadUsSuccess = $false


for ($i = 0; $i -lt 200 -and ($jobsCompleted -lt 2); $i++) 
{
	Start-Sleep -Milliseconds 100

	if((Get-Job -Id $downloadJobEu.Id -ErrorAction SilentlyContinue).State -eq "Completed")
	{
		$downloadEuSuccess = (Receive-Job -Id $downloadJobEu.Id) -contains "DownloadSuccess"
		$jobsCompleted++
		Remove-Job -Id $downloadJobEu.Id
	}

	if((Get-Job -Id $downloadJobUs.Id -ErrorAction SilentlyContinue).State -eq "Completed")
	{
		$downloadUsSuccess = (Receive-Job -Id $downloadJobUs.Id) -contains "DownloadSuccess"
		$jobsCompleted++
		Remove-Job -Id $downloadJobUs.Id
	}

}

Stop-Job -Id $downloadJobEu.Id, $downloadJobUs.Id -ErrorAction SilentlyContinue

if(-not ($downloadEuSuccess -or $downloadUsSuccess))
{
	Write-Host "Download from US and EU servers failed. Check your internet connection."
	return -1
}

$chosenServer = "EU"
$url = $urlEu

$fileLengthEu = (Get-Item $fileLocationEu -ErrorAction SilentlyContinue).Length
$fileLengthUs = (Get-Item $fileLocationUs -ErrorAction SilentlyContinue).Length

if($fileLengthEu -lt $fileLengthUs)
{
	$chosenServer = "US"
	$url = $urlUs
}

Write-Host "Connection to the $chosenServer servers was faster. Starting download from the $chosenServer servers."


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

Remove-Item $fileLocationEu, $fileLocationUs, $fileLocation -ErrorAction SilentlyContinue