$files = Get-ChildItem -Path '.' -Recurse -Include *.gd,*.tscn,*.tres,*.json | Where-Object { $_.FullName -notmatch '\\.godot|\\.git|android\\build' }

$results = @()
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $chars = $content.ToCharArray()
    $bad = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($c in $chars) {
        $ci = [int]$c
        # standard ascii is 0..127
        # standard spanish / western european is 160..255
        # 0x2022 is •, 0x25C6 is ◆, 0x2014 is —, 0x2013 is –, 0x2026 is …
        if ($ci -gt 127) {
            $is_spanish = ($ci -ge 160 -and $ci -le 255)
            $is_known_symbol = ($ci -eq 0x2022 -or $ci -eq 0x25C6 -or $ci -eq 0x2014 -or $ci -eq 0x2013 -or $ci -eq 0x2026)
            if (-not $is_spanish -and -not $is_known_symbol) {
                $hex = "U+{0:X4}" -f $ci
                $bad.Add($hex) | Out-Null
            }
        }
    }
    if ($bad.Count -gt 0) {
        $rel = $f.FullName.Replace("d:\workspace\TaosProyect\TaosGameMaker_Proyecto\", "")
        $results += [PSCustomObject]@{
            File = $rel
            Chars = ($bad -join ", ")
        }
    }
}

$results | Format-Table -AutoSize | Out-String -Width 200
