$files = Get-ChildItem -Path 'data\cinematics\*.json'
foreach ($f in $files) {
    $c = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $c2 = [System.Text.RegularExpressions.Regex]::Replace($c, '"portrait":\s*"[^"]*"', '"portrait": ""')
    [System.IO.File]::WriteAllText($f.FullName, $c2, [System.Text.Encoding]::UTF8)
    Write-Output ("Cleaned: " + $f.Name)
}
