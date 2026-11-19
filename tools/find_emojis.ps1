$files = Get-ChildItem -Path 'scenes','scripts','data' -Recurse -Include *.gd,*.tscn,*.json
$matches_list = [System.Collections.ArrayList]::new()

foreach ($f in $files) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $chars = $line.ToCharArray()
        $found = $false
        for ($j = 0; $j -lt $chars.Length; $j++) {
            $code = [int]$chars[$j]
            # Surrogate pairs (emojis 0xD800..0xDFFF) or symbols range (0x2600..0x27BF except standard bullets)
            if (($code -ge 0xD800 -and $code -le 0xDFFF) -or ($code -ge 0x2600 -and $code -le 0x27BF)) {
                $found = $true
                break
            }
        }
        if ($found) {
            $rel = $f.FullName.Replace('D:\workspace\TaosProyect\TaosGameMaker_Proyecto\', '')
            $snippet = if ($line.Trim().Length -gt 70) { $line.Trim().Substring(0, 70) } else { $line.Trim() }
            $matches_list.Add([PSCustomObject]@{
                File = $rel
                Line = $i + 1
                Snippet = $snippet
            }) | Out-Null
        }
    }
}

Write-Output ("Total matching lines: " + $matches_list.Count)
$matches_list | Format-Table -AutoSize | Out-String -Width 220
