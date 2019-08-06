

$url      = 'http://static.voobly.com/updates/voobly-v2.2.5.65-update-full.exe'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$size     = (Invoke-WebRequest $url -Method Head).Headers["Content-Length"]

$filePath = "eu11.exe"

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
    Write-Host $lower + " - " + $upper
    $response = $request.GetResponse()
    
    
    $responseBody = $response.GetResponseStream()
    $br = New-Object System.IO.BinaryReader -ArgumentList $responseBody


    # $buf =  [System.Byte[]]::CreateInstance([System.Byte], $chunkSize)
    # $br.Read($buf, 0, $chunkSize) | Out-Null
    # $bw.Write($buf, 0, [Math]::min($chunkSize, $size - $i * $chunkSize)) | Out-Null

    
    #$buf =  [System.Byte[]]::CreateInstance([System.Byte], $size)
    $buf = $br.ReadBytes($chunkSize)
    $bw.Write($buf, 0, [Math]::min($chunkSize, $size - $i * $chunkSize))

    $progress = $i * $chunkSize / $size
    Write-Output $progress
}
$br.Close()
$bw.Close()
$fs.Close()

