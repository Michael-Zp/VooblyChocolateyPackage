
$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url 		= ''
$url64      = ''
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$fileLocation = "$toolsDir/install.exe"
$fileLocationEu = "$toolsDir/installEu.exe"
$fileLocationUs = "$toolsDir/installUs.exe"


$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  file          = $fileLocation

  softwareName  = 'testDownload*'

  checksum      = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType  = 'sha256'
  checksum64    = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType64= 'sha256'

  silentArgs   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}


$modulePaths = Get-Module -All | Select-Object -ExpandProperty Path

$jobCodeMeasure = 
{
    Param($pn, $fl, $url, $url64, $modulePaths, $downloadSuccess)

	$startDownloadTrigger = "StartedDownload"

    $jobCodeDownload = {
		Param($pn, $fl, $url, $url64, $modulePaths, $startDownloadTrigger)
		$modulePaths | Import-Module
	
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Write-Output $startDownloadTrigger
		Get-ChocolateyWebFile -PackageName $pn -FileFullPath $fl -Url $url -Url64bit $url64
	}
	  
	$downloadJob = Start-Job -ScriptBlock $jobCodeDownload -ArgumentList $pn, $fl, $url, $url64, $modulePaths, $startDownloadTrigger

    $running = $true

    while ($running) 
    {
        Start-Sleep -Milliseconds 100
        if($running -and (Receive-Job -Id $downloadJob.Id) -eq $startDownloadTrigger)
        {
			$fileDoesExist = $true
			for ($i = 0; $i -lt 200; $i++) 
			{
				if(Test-Path $fl)
				{
					$fileDoesExist = $true
					break
				}
				Start-Sleep -Milliseconds 50
			}

			Start-Sleep -Seconds 1

			$fileDoesExist = Test-Path $fl
			
			Stop-Job -Id $downloadJob.Id
			$running = $false

			if($fileDoesExist)
			{
				Write-Output $downloadSuccess
			}
        }
    }
}

$downloadSuccess = "DownloadSuccess"

Write-Host "Testing download speed to US and EU servers."

$downloadJobEu = Start-Job -ScriptBlock $jobCodeMeasure -ArgumentList $packageName, $fileLocationEu, $urlEu, $urlEu, $modulePaths, $downloadSuccess
$downloadJobUs = Start-Job -ScriptBlock $jobCodeMeasure -ArgumentList $packageName, $fileLocationUs, $urlUs, $urlUs, $modulePaths, $downloadSuccess

$runningEu = $true
$downloadEuSuccess = $false
$runningUs = $true
$downloadUsSuccess = $false

$completedState = "Completed"

while ($runningEu -or $runningUs)
{
	Start-Sleep -Milliseconds 50
	if($runningEu -and (Get-Job -Id $downloadJobEu.Id).State -eq $completedState)
	{
		$state = Receive-Job -Id $downloadJobEu.Id
		if($state -eq $downloadSuccess)
		{
			$downloadEuSuccess = $true
		}
		$runningEu = $false
	}

	if($runningUs -and (Get-Job -Id $downloadJobUs.Id).State -eq $completedState)
	{
		$state = Receive-Job -Id $downloadJobUs.Id
		if($state -eq $downloadSuccess)
		{
			$downloadUsSuccess = $true
		}
		$runningUs = $false
	}
}

if(-not $downloadEuSuccess -and -not $downloadUsSuccess)
{
	Write-Host "Download from US and EU servers failed. Check your internet connection."
	return -1
}

$downloadFromEuServer = $false
$downloadFromUsServer = $false

if((Get-Item $fileLocationEu).Length -lt (Get-Item $fileLocationUs).Length)
{
	if($downloadEuSuccess)
	{
		$downloadFromEuServer = $true
	}
	elseif($downloadUsSuccess) 
	{
		$downloadFromUsServer = $true
	}
}
else
{
	if($downloadUsSuccess) 
	{
		$downloadFromEuServer = $true
	}
	elseif($downloadEuSuccess)
	{
		$downloadFromUsServer = $true
	}
}

$chosenServer = "ChosenServer"

if($downloadFromEuServer)
{
	$chosenServer = "EU"
	$url = $urlEu
	$url64 = $urlEu
}

if($downloadFromUsServer)
{
	$chosenServer = "US"
	$url = $urlUs
	$url64 = $urlUs
}

Write-Host "Connection from the $chosenServer server was faster. Starting download from the $chosenServer server."

Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $fileLocation -Url $url -Url64bit $url64

Install-ChocolateyPackage @packageArgs










    








