param(
    [string]$SrcPath = "C:\Users\Taos\.gemini\antigravity-ide\brain\a9ef70d5-83d8-495c-a732-c779bb7b4ec9\google_play_feature_graphic_1791980602463.jpg",
    [string]$OutJpg = "d:\workspace\TaosProyect\google_play_feature_graphic_1024x500.jpg",
    [string]$OutPng = "d:\workspace\TaosProyect\google_play_feature_graphic_1024x500.png"
)

Add-Type -AssemblyName System.Drawing

$srcImg = [System.Drawing.Image]::FromFile($SrcPath)
$targetW = 1024
$targetH = 500
$targetRatio = $targetW / $targetH
$srcRatio = $srcImg.Width / $srcImg.Height

if ($srcRatio -gt $targetRatio) {
    $cropH = $srcImg.Height
    $cropW = [int]($srcImg.Height * $targetRatio)
    $cropX = [int](($srcImg.Width - $cropW) / 2)
    $cropY = 0
} else {
    $cropW = $srcImg.Width
    $cropH = [int]($srcImg.Width / $targetRatio)
    $cropX = 0
    $cropY = [int](($srcImg.Height - $cropH) / 2)
}

$bmp = New-Object System.Drawing.Bitmap($targetW, $targetH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$dstRect = New-Object System.Drawing.Rectangle(0, 0, $targetW, $targetH)
$g.DrawImage($srcImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

$srcImg.Dispose()

$bmp.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png)

$encoder = [System.Drawing.Imaging.Encoder]::Quality
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]95)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$bmp.Save($OutJpg, $codec, $encoderParams)

$bmp.Dispose()
$g.Dispose()

Write-Output "SUCCESS: Generated 1024x500 images at $OutPng and $OutJpg"
