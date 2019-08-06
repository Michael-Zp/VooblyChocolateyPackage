


$jobCode = {

    Param($url, $size, $filePath)

    Add-Type -AssemblyName System.Net.Http | Out-Null

    $fs = New-Object System.IO.FileStream -ArgumentList $filePath, Append, Write
    $bw = New-Object System.IO.BinaryWriter -ArgumentList $fs

    $chunkSize = 250000
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $request = [System.Net.HttpWebRequest]::Create($url)


    for ($i = 0; $i -lt $size / $chunkSize; $i++) {
        $lower = $i * $chunkSize
        $upper = [Math]::min($size, ($i + 1) * $chunkSize)
        
        $request.AddRange($lower, $upper)
        $response = $request.GetResponse()
        
        
        $responseBody = $response.GetResponseStream()
        $br = New-Object System.IO.BinaryReader -ArgumentList $responseBody


        $buf =  [System.Byte[]]::CreateInstance([System.Byte], $chunkSize)
        $br.Read($buf, 0, $chunkSize) | Out-Null
        $bw.Write($buf, 0, [Math]::min($chunkSize, $size - $i * $chunkSize)) | Out-Null

        $progress = $i * $chunkSize / $size
        Write-Output $progress
    }
    $br.Close()
    $bw.Close()
    $fs.Close()

}


$urlUs      = 'http://update.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'
$urlEu      = 'http://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sizeUs     = (Invoke-WebRequest $urlUs -Method Head).Headers["Content-Length"]
$sizeEu     = (Invoke-WebRequest $urlEu -Method Head).Headers["Content-Length"]



$jobUs = Start-Job -ScriptBlock $jobCode -ArgumentList $urlUs, $sizeUs, "us.exe"
$jobEu = Start-Job -ScriptBlock $jobCode -ArgumentList $urlEu, $sizeEu, "eu.exe"

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

