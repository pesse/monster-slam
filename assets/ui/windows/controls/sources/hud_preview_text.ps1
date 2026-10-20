$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDir = Split-Path -Parent $PSScriptRoot
$fontDir = [System.IO.Path]::GetFullPath((Join-Path $assetDir '..\..\..\fonts\fira_sans'))
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $fontDir 'FiraSans-SemiBold.ttf'))
$semi = $fonts.Families | Select-Object -First 1
$path = Join-Path $assetDir 'preview\hud-1152.png'
$inputImage = [System.Drawing.Image]::FromFile($path)
$bitmap = New-Object System.Drawing.Bitmap($inputImage)
$inputImage.Dispose()
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$white = [System.Drawing.Color]::FromArgb(235, 241, 252)
$muted = [System.Drawing.Color]::FromArgb(164, 181, 207)
$gold = [System.Drawing.Color]::FromArgb(255, 217, 112)
function Draw-Text([string]$text, [single]$x, [single]$y, [single]$size = 20, $color = $white, [single]$centerWidth = 0) {
    $glyphs = New-Object System.Drawing.Drawing2D.GraphicsPath
    $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $glyphs.AddString($text, $semi, 0, $size, (New-Object System.Drawing.PointF($x, $y)), $format)
    if ($centerWidth -gt 0) {
        $bounds = $glyphs.GetBounds()
        $matrix = New-Object System.Drawing.Drawing2D.Matrix
        $matrix.Translate(($x + ($centerWidth - $bounds.Width) / 2 - $bounds.X), 0)
        $glyphs.Transform($matrix)
        $matrix.Dispose()
    }
    $shadow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(5, 10, 23), 2)
    $shadow.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawPath($shadow, $glyphs)
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillPath($brush, $glyphs)
    $shadow.Dispose()
    $brush.Dispose()
    $glyphs.Dispose()
    $format.Dispose()
}
Draw-Text ('Schattenf' + [char]0x00fc + 'rst') 144 57 25
Draw-Text '70 %' 984 67 18 $white
Draw-Text 'Satz 1 von 5' 48 194 20 $white 184
Draw-Text 'Grund-Geschwindigkeit' 48 252 22
Draw-Text '50 %' 714 257 17 $gold
Draw-Text 'Erfahrung' 48 356 22
Draw-Text '30 %' 714 361 17 $gold
Draw-Text 'Bildlauf' 872 252 22
Draw-Text 'Normal' 856 282 13 $muted 80
Draw-Text 'Hover' 936 282 13 $muted 80
Draw-Text ('Gedr' + [char]0x00fc + 'ckt') 1016 282 13 $gold 80
Draw-Text ('Modulierbare F' + [char]0x00fc + 'llung') 48 480 20
Draw-Text 'Lebenspunkte' 48 550 14 $muted
Draw-Text 'Warnung' 248 550 14 $muted
Draw-Text 'Energie' 448 550 14 $muted
Draw-Text '16 px' 688 550 14 $muted
Draw-Text 'Griff: Normal / Hover' 140 588 16 $muted
# Heart placeholder exists only in the preview, never in a runtime texture.
$heart = New-Object System.Drawing.Drawing2D.GraphicsPath
$heart.StartFigure()
$heart.AddBezier(99, 83, 72, 59, 66, 92, 99, 112)
$heart.AddBezier(99, 112, 132, 91, 125, 60, 99, 83)
$heart.CloseFigure()
$heartFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(184, 42, 65))
$heartStroke = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(242, 147, 160), 2)
$graphics.FillPath($heartFill, $heart)
$graphics.DrawPath($heartStroke, $heart)
$heartFill.Dispose()
$heartStroke.Dispose()
$heart.Dispose()
$graphics.Dispose()
$bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
$fonts.Dispose()
Write-Output 'HUD preview: Fira Sans text and heart placeholder added; no old previews touched.'
