<#
.SYNOPSIS
    Generates the Inno Setup wizard bitmaps in installer\. Run after changing
    the design; never hand-edit the BMPs.
.DESCRIPTION
    Vector-draws the installer art with WPF and writes the four 24-bit BMPs
    the .iss references (Inno accepts only BMP here, no alpha):

        wizard-image-100.bmp   164x314  left panel of the welcome/finish pages
        wizard-image-200.bmp   328x628  same, for 200% DPI
        wizard-small-100.bmp    55x55   top-right tile of the inner pages
        wizard-small-200.bmp   110x110  same, for 200% DPI

    Design: the app's branding - near-black background matching the UI shell,
    the white AirPlay glyph (same path data as GlyphIdle/GlyphLive in
    airplay-ui.ps1; keep in sync), and the AirPlayPC wordmark on the tall
    panel. Replaces Inno's stock box-and-disc drawing.
#>
param(
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'installer'
}

function New-Color([string]$Hex) {
    [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
}

# The UI's hero mark, verbatim (52x52 box; bounds x 2..50, y 3..50,
# bounds center 26, 26.5).
$script:GlyphScreen = [System.Windows.Media.Geometry]::Parse(
    'M 19,36 H 7 A 5,5 0 0 1 2,31 V 8 A 5,5 0 0 1 7,3 H 45 A 5,5 0 0 1 50,8 V 31 A 5,5 0 0 1 45,36 H 33')
$script:GlyphTriangle = [System.Windows.Media.Geometry]::Parse('M 26,30 L 42,50 L 10,50 Z')

function Draw-Glyph($dc, [double]$CenterX, [double]$CenterY, [double]$Scale, [double]$Thickness) {
    $dc.PushTransform((New-Object System.Windows.Media.TranslateTransform ($CenterX - 26 * $Scale), ($CenterY - 26.5 * $Scale)))
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform $Scale, $Scale))
    $white = New-Object System.Windows.Media.SolidColorBrush (New-Color '#FFFFFF')
    $pen = New-Object System.Windows.Media.Pen $white, $Thickness
    $pen.StartLineCap = 'Round'; $pen.EndLineCap = 'Round'; $pen.LineJoin = 'Round'
    $dc.DrawGeometry($null, $pen, $script:GlyphScreen)
    $dc.DrawGeometry($white, $null, $script:GlyphTriangle)
    $dc.Pop()
    $dc.Pop()
}

function New-WizardImageSource([int]$W, [int]$H) {
    # Logical space is the 100% size (164x314); scale up for the DPI variants.
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform ($W / 164.0), ($H / 314.0)))

    # Background: the UI shell's dark vertical gradient.
    $bg = New-Object System.Windows.Media.LinearGradientBrush
    $bg.StartPoint = New-Object System.Windows.Point 0, 0
    $bg.EndPoint   = New-Object System.Windows.Point 0, 1
    [void]$bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#13151A'), 0.0))
    [void]$bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#0A0B0D'), 0.45))
    [void]$bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#050506'), 1.0))
    $dc.DrawRectangle($bg, $null, (New-Object System.Windows.Rect 0, 0, 164, 314))

    # Soft blue halo behind the mark, like the UI's live glow (subtle - this
    # sits next to black, so a little goes a long way).
    $halo = New-Object System.Windows.Media.RadialGradientBrush
    [void]$halo.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#2E0A84FF'), 0.0))
    [void]$halo.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#100A84FF'), 0.5))
    [void]$halo.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#000A84FF'), 1.0))
    $dc.DrawEllipse($halo, $null, (New-Object System.Windows.Point 82, 118), 78, 78)

    Draw-Glyph $dc 82.0 118.0 2.0 2.6

    # Wordmark under the mark.
    $tf = New-Object System.Windows.Media.Typeface (
        (New-Object System.Windows.Media.FontFamily 'Segoe UI'),
        [System.Windows.FontStyles]::Normal,
        [System.Windows.FontWeights]::SemiBold,
        [System.Windows.FontStretches]::Normal)
    $ft = New-Object System.Windows.Media.FormattedText 'AirPlayPC',
        ([System.Globalization.CultureInfo]::InvariantCulture),
        ([System.Windows.FlowDirection]::LeftToRight), $tf, 19.0,
        (New-Object System.Windows.Media.SolidColorBrush (New-Color '#F5F5F7'))
    $dc.DrawText($ft, (New-Object System.Windows.Point (82 - $ft.Width / 2), 186))

    $dc.Pop()
    $dc.Close()

    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap $W, $H, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $rtb
}

function New-SmallImageSource([int]$Size) {
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $s = $Size / 55.0
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform $s, $s))
    $dc.DrawRectangle((New-Object System.Windows.Media.SolidColorBrush (New-Color '#0B0C10')), $null,
        (New-Object System.Windows.Rect 0, 0, 55, 55))
    Draw-Glyph $dc 27.5 27.5 0.72 3.0
    $dc.Pop()
    $dc.Close()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $rtb
}

function Save-Bmp($Source, [string]$Path) {
    # Inno wants classic BMP; drop alpha via Bgr24 (background is opaque anyway).
    $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap
    $conv.BeginInit(); $conv.Source = $Source
    $conv.DestinationFormat = [System.Windows.Media.PixelFormats]::Bgr24
    $conv.EndInit()
    $enc = New-Object System.Windows.Media.Imaging.BmpBitmapEncoder
    [void]$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($conv))
    $fs = [System.IO.File]::Create($Path)
    try { $enc.Save($fs) } finally { $fs.Dispose() }
    Write-Host ("OK: {0}  ({1:N0} bytes)" -f $Path, (Get-Item $Path).Length)
}

Save-Bmp (New-WizardImageSource 164 314) (Join-Path $OutDir 'wizard-image-100.bmp')
Save-Bmp (New-WizardImageSource 328 628) (Join-Path $OutDir 'wizard-image-200.bmp')
Save-Bmp (New-SmallImageSource 55)       (Join-Path $OutDir 'wizard-small-100.bmp')
Save-Bmp (New-SmallImageSource 110)      (Join-Path $OutDir 'wizard-small-200.bmp')
