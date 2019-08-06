$ErrorActionPreference = 'Stop'; 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$urlUs      = 'https://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlEu      = 'https://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

do {
  $tempFile = [System.IO.Path]::GetTempFileName()
  $fileName = Split-Path $tempFile -Leaf
  $exeUs = ".\$($fileName -replace ".tmp",".exe")"
  Remove-Item $tempFile
} while (Test-Path $exeUs)

do {
  $tempFile = [System.IO.Path]::GetTempFileName()
  $fileName = Split-Path $tempFile -Leaf
  $exeEu = ".\$($fileName -replace ".tmp",".exe")"
  Remove-Item $tempFile
} while (Test-Path $exeEu)

$jobCode = {

  Param($url, $size, $filePath)

  Add-Type -AssemblyName System.Net.Http | Out-Null

  $fs = New-Object System.IO.FileStream -ArgumentList $filePath, Append, Write
  $bw = New-Object System.IO.BinaryWriter -ArgumentList $fs

  $chunkSize = 250000
  
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


  for ($i = 0; $i -lt $size / $chunkSize; $i++) {
      $lower = $i * $chunkSize
      $upper = [Math]::min($size, ($i + 1) * $chunkSize - 1)
      
      $request = [System.Net.HttpWebRequest]::Create($url)
      $request.ContentType = 'application/x-msdos-program'
      $request.AddRange($lower, $upper)
      $response = $request.GetResponse()
      
      
      $responseBody = $response.GetResponseStream()
      $br = New-Object System.IO.BinaryReader -ArgumentList $responseBody

      $buf = $br.ReadBytes($chunkSize)
      $bw.Write($buf, 0, [Math]::min($chunkSize, $size - $i * $chunkSize)) | Out-Null

      $progress = $i * $chunkSize / $size
      Write-Output $progress
  }
  $br.Close()
  $bw.Close()
  $fs.Close()

}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sizeUs     = (Invoke-WebRequest $urlUs -Method Head).Headers["Content-Length"]
$sizeEu     = (Invoke-WebRequest $urlEu -Method Head).Headers["Content-Length"]



$jobUs = Start-Job -ScriptBlock $jobCode -ArgumentList $urlUs, $sizeUs, $exeUs
$jobEu = Start-Job -ScriptBlock $jobCode -ArgumentList $urlEu, $sizeEu, $exeEu

$runningState = "Running"
$percentage = 0
$percentageSteps = 0.1

$resultUs = 0
$resultEu = 0

$statusUs = $false
$statusEu = $false
$sleepMilliseconds = 100

for ($i = 0; $i -lt (60 * 60 * (1000 / $sleepMilliseconds)); $i++) {

  $statusUs = (Get-Job -Id $jobUs.Id).State -ne $runningState
  $statusEu = (Get-Job -Id $jobEu.Id).State -ne $runningState

  $tempResultUs = (Receive-Job -Id $jobUs.Id)
  $tempResultEu = (Receive-Job -Id $jobEu.Id)
  
  if($null -ne $tempResultEu)
  {
      $resultEu = $tempResultEu[$tempResultEu.Length - 1]
  }

  if($null -ne $tempResultUs)
  {
      $resultUs = $tempResultUs[$tempResultUs.Length - 1]
  }
  
  $result = [Math]::Max($resultUs, $resultEu)

  if($result -gt $percentage + $percentageSteps)
  {
      $percentage += $percentageSteps
      $dispPerc = $percentage * 100
      Write-Host "$dispPerc% ... " -NoNewline
  }

  if(($statusUs -or $statusEu) -and $percentage -ge 0.85)
  {
      Stop-Job $jobUs.Id
      Stop-Job $jobEu.Id
      Write-Host "100%"
      break
  }

  Start-Sleep -Milliseconds $sleepMilliseconds
}

if($statusUs)
{
  $fileLocation = $exeUs
}
else
{
  $fileLocation = $exeEu
}

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE_MSI_OR_MSU'
  file          = $fileLocation

  softwareName  = 'Voobly*'

  checksum      = 'F1691F7F45B68E638F47AC9B97BCC02C180F82389B3DAEF3DF3CEB131CE06D69'
  checksumType  = 'sha256'
  checksum64    = $checksum
  checksumType64= $checksumType

  silentArgs   = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}

Install-ChocolateyPackage @packageArgs 


while($null -eq (Get-Process | Where-Object { $_.Name -eq 'voobly' }))
{
    Start-Sleep -Milliseconds 25
}

Stop-Process -Name 'voobly'

Remove-Item $exeUs -ErrorAction SilentlyContinue
Remove-Item $exeEu -ErrorAction SilentlyContinue