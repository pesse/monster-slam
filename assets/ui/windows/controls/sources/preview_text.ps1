$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDir = Split-Path -Parent $PSScriptRoot
$fontDir = [System.IO.Path]::GetFullPath((Join-Path $assetDir '..\..\..\fonts\fira_sans'))
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $fontDir 'FiraSans-SemiBold.ttf'))
$fonts.AddFontFile((Join-Path $fontDir 'FiraSans-Bold.ttf'))
$semi = $fonts.Families | Where-Object Name -eq 'Fira Sans SemiBold' | Select-Object -First 1
$bold = $fonts.Families | Where-Object Name -eq 'Fira Sans' | Select-Object -First 1
if (-not $semi) { throw 'Local Fira Sans SemiBold did not load' }
if (-not $bold) { $bold = $semi }
$previewPath = Join-Path $assetDir 'preview\controls-1152.png'
$inputImage = [System.Drawing.Image]::FromFile($previewPath)
$bitmap = New-Object System.Drawing.Bitmap($inputImage)
$inputImage.Dispose()
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$white = [System.Drawing.Color]::FromArgb(235, 241, 252)
$gold = [System.Drawing.Color]::FromArgb(255, 216, 100)
$muted = [System.Drawing.Color]::FromArgb(155, 170, 193)
$dark = [System.Drawing.Color]::FromArgb(3, 9, 18)
function Draw-Text([string]$text, [single]$x, [single]$y, [single]$size = 20, $color = $white, [single]$outline = 0, [single]$centerWidth = 0) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $style = [System.Drawing.FontStyle]::Regular
    $path.AddString($text, $semi, [int]$style, $size, (New-Object System.Drawing.PointF($x, $y)), $format)
    if ($centerWidth -gt 0) {
        $bounds = $path.GetBounds()
        $matrix = New-Object System.Drawing.Drawing2D.Matrix
        $matrix.Translate(($x + ($centerWidth - $bounds.Width) / 2 - $bounds.X), 0)
        $path.Transform($matrix)
        $matrix.Dispose()
    }
    if ($outline -gt 0) {
        # A 2*radius stroke places a true 4px contour outside the glyph.
        $pen = New-Object System.Drawing.Pen($dark, ($outline * 2))
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $graphics.DrawPath($pen, $path)
        $pen.Dispose()
    }
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
    $format.Dispose()
}
Draw-Text 'Profilname' 32 26 22
Draw-Text 'Sam' 44 72 20
Draw-Text 'Sam' 44 134 20
Draw-Text 'Sam' 836 134 20 $muted
Draw-Text 'Umbenennen' 408 72 20 $white 2 184
Draw-Text 'Fokus' 612 74 16 $muted
Draw-Text 'Ohne Fokus' 408 136 16 $muted
Draw-Text 'Nur lesen' 824 98 16 $muted
$caretPen = New-Object System.Drawing.Pen($gold, 2)
$graphics.DrawLine($caretPen, 84, 72, 84, 96)
$caretPen.Dispose()
Draw-Text 'Standard-Schwierigkeit' 32 193 22
Draw-Text 'Grafik' 600 193 22
for ($i = 0; $i -lt 5; $i++) {
    $color = if ($i -eq 2) { $gold } else { $white }
    Draw-Text ([string]($i + 1)) (32 + $i * 44) 232 20 $color 4 44
}
Draw-Text '3 gewaehlt / 4 Hover' 280 236 16 $muted
Draw-Text ('Sch' + [char]0x00f6 + 'n') 600 232 20 $gold 4 128
Draw-Text 'Mittel' 728 232 20 $white 4 128
Draw-Text 'Schnell' 856 232 20 $white 4 128
Draw-Text 'Schwierigkeit' 32 303 20
$labels = @('Viel leichter', 'Leichter', 'Normal', 'Schwieriger', 'Viel schwieriger')
$widths = @(192, 192, 192, 192, 220)
$left = 32
for ($i = 0; $i -lt 5; $i++) {
    $color = if ($i -eq 2) { $gold } elseif ($i -eq 4) { $muted } else { $white }
    Draw-Text $labels[$i] $left 340 20 $color 4 $widths[$i]
    $left += $widths[$i]
}
$checkLabels = @('An', 'Aus', 'An, gesperrt', 'Aus, gesperrt')
for ($i = 0; $i -lt 4; $i++) {
    $color = if ($i -ge 2) { $muted } else { $white }
    Draw-Text 'Beim Tippen bleibt die Zeit stehen' 80 (432 + $i * 50) 20 $color
    Draw-Text $checkLabels[$i] 916 (434 + $i * 50) 16 $muted
}
$graphics.Dispose()
$bitmap.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
$comparePath = Join-Path $assetDir 'preview\compare-v1.png'
$inputImage = [System.Drawing.Image]::FromFile($comparePath)
$bitmap = New-Object System.Drawing.Bitmap($inputImage)
$inputImage.Dispose()
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
Draw-Text 'V1: Originalregionen, Bedienelemente auf 44 px skaliert' 24 4 16 $muted
Draw-Text 'Laufzeit: exportierte Texturen, dieselben Positionen und Abmessungen' 24 174 16 $muted
Draw-Text 'Standard-Schwierigkeit' 24 86 20
Draw-Text 'Grafik' 620 86 20
Draw-Text 'Standard-Schwierigkeit' 24 256 20
Draw-Text 'Grafik' 620 256 20
Draw-Text 'Sam' 36 214 20
Draw-Text 'Umbenennen' 404 214 20 $white 2 208
$caretPen = New-Object System.Drawing.Pen($gold, 2)
$graphics.DrawLine($caretPen, 80, 214, 80, 238)
$caretPen.Dispose()
$left = 24
$comparisonWidths = @(52, 53, 53, 54, 57)
for ($i = 0; $i -lt 5; $i++) {
    $color = if ($i -eq 2) { $gold } else { $white }
    Draw-Text ([string]($i + 1)) $left 294 20 $color 4 $comparisonWidths[$i]
    $left += $comparisonWidths[$i]
}
Draw-Text ('Sch' + [char]0x00f6 + 'n') 620 294 20 $gold 4 97
Draw-Text 'Mittel' 717 294 20 $white 4 107
Draw-Text 'Schnell' 824 294 20 $white 4 110
$graphics.Dispose()
$bitmap.Save($comparePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
$fonts.Dispose()
Write-Output 'Preview text: local Fira Sans SemiBold, 20px; group contour radius 4px.'
