$proc = (Get-Process | Where-Object { $_.Name -eq 'voobly' })
if($null -ne $proc)
{
    Stop-Process $proc
}