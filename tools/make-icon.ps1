<#
.SYNOPSIS
    Generates pcairplay.ico at the repo root. Run after changing the design.
.DESCRIPTION
    Vector-draws the app icon with WPF (so it stays crisp at every size) and
    packs a proper multi-size .ico: 256 as a PNG entry, the rest as classic
    32-bit BGRA BMP entries with AND masks - the only combination every
    Windows consumer (Explorer, taskbar, tray, Inno Setup) renders correctly.

    Design: near-black rounded square matching the UI's tvOS-dark look, with
    the UI's own hero mark - the AirPlay glyph (screen outline with the
    triangle rising through its bottom edge) - centered in white. Same path
    data as GlyphIdle/GlyphLive in airplay-ui.ps1; keep them in sync.
    (Explicit user decision 2026-07-20 to brand with this glyph, replacing
    the earlier phone-outline-plus-arcs design.)
#>
param(
    [string]$OutPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

if (-not $OutPath) {
    $OutPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'pcairplay.ico'
}

function New-Color([string]$Hex) {
    [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
}

function New-VerticalBrush([string]$Top, [string]$Bottom) {
    $b = New-Object System.Windows.Media.LinearGradientBrush
    $b.StartPoint = New-Object System.Windows.Point 0, 0
    $b.EndPoint   = New-Object System.Windows.Point 0, 1
    [void]$b.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color $Top), 0.0))
    [void]$b.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color $Bottom), 1.0))
    $b
}

function New-IconSource([int]$Size) {
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $s = $Size / 256.0
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform $s, $s))

    # Chassis: rounded square, subtle vertical gradient, hairline border.
    $bgRect = New-Object System.Windows.Rect 2, 2, 252, 252
    $dc.DrawRoundedRectangle((New-VerticalBrush '#252833' '#0B0C10'),
        (New-Object System.Windows.Media.Pen (New-Object System.Windows.Media.SolidColorBrush (New-Color '#3C4150')), 3),
        $bgRect, 56, 56)

    # Soft top sheen so the tile reads as glass rather than flat paint.
    $sheen = New-Object System.Windows.Media.LinearGradientBrush
    $sheen.StartPoint = New-Object System.Windows.Point 0, 0
    $sheen.EndPoint   = New-Object System.Windows.Point 0, 1
    [void]$sheen.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#26FFFFFF'), 0.0))
    [void]$sheen.GradientStops.Add((New-Object System.Windows.Media.GradientStop (New-Color '#00FFFFFF'), 0.42))
    $dc.DrawRoundedRectangle($sheen, $null, (New-Object System.Windows.Rect 2, 2, 252, 252), 56, 56)

    # The AirPlay glyph, exactly as the UI's hero mark draws it (52x52 box:
    # screen outline x 2..50 / y 3..36 with the bottom gap, triangle apex at
    # y 30 poking through). Bounds center (26, 26.5); scale + translate so it
    # sits optically centered at ~63% of the tile.
    $glyphScreen = [System.Windows.Media.Geometry]::Parse(
        'M 19,36 H 7 A 5,5 0 0 1 2,31 V 8 A 5,5 0 0 1 7,3 H 45 A 5,5 0 0 1 50,8 V 31 A 5,5 0 0 1 45,36 H 33')
    $glyphTriangle = [System.Windows.Media.Geometry]::Parse('M 26,30 L 42,50 L 10,50 Z')
    $k = 3.4
    $dc.PushTransform((New-Object System.Windows.Media.TranslateTransform (128 - 26 * $k), (128 - 26.5 * $k)))
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform $k, $k))
    $white = New-Object System.Windows.Media.SolidColorBrush (New-Color '#FFFFFF')
    # 3.0 glyph units = ~10 px at 256: reads at 16 px where the UI's 2.4 would thin out.
    $glyphPen = New-Object System.Windows.Media.Pen $white, 3.0
    $glyphPen.StartLineCap = 'Round'; $glyphPen.EndLineCap = 'Round'; $glyphPen.LineJoin = 'Round'
    $dc.DrawGeometry($null, $glyphPen, $glyphScreen)
    $dc.DrawGeometry($white, $null, $glyphTriangle)
    $dc.Pop()
    $dc.Pop()

    $dc.Pop()
    $dc.Close()

    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    # ICO stores STRAIGHT alpha; Pbgra32 is premultiplied - convert.
    $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap
    $conv.BeginInit(); $conv.Source = $rtb
    $conv.DestinationFormat = [System.Windows.Media.PixelFormats]::Bgra32
    $conv.EndInit()
    $conv
}

function Get-PngBytes($Source) {
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    [void]$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($Source))
    $ms = New-Object System.IO.MemoryStream
    $enc.Save($ms)
    # Unary comma: without it PowerShell unrolls the byte[] into the pipeline
    # and the caller receives object[], which BinaryWriter.Write() silently
    # coerces to Boolean - one 0x01 byte instead of the image. Cost a debug
    # round; the directory lengths stay right, so only the data is garbage.
    , $ms.ToArray()
}

function Get-BmpIconEntryBytes($Source, [int]$Size) {
    $stride = $Size * 4
    $pixels = New-Object byte[] ($stride * $Size)
    $Source.CopyPixels($pixels, $stride, 0)

    $andStride = [int]([Math]::Ceiling($Size / 32.0) * 4)
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter $ms
    # BITMAPINFOHEADER - biHeight is DOUBLE (XOR + AND blocks).
    $w.Write([int32]40); $w.Write([int32]$Size); $w.Write([int32]($Size * 2))
    $w.Write([int16]1); $w.Write([int16]32); $w.Write([int32]0)
    $w.Write([int32]($stride * $Size + $andStride * $Size))
    $w.Write([int32]0); $w.Write([int32]0); $w.Write([int32]0); $w.Write([int32]0)
    # XOR block, bottom-up.
    for ($y = $Size - 1; $y -ge 0; $y--) {
        $w.Write($pixels, $y * $stride, $stride)
    }
    # AND mask: all zero (alpha channel rules), bottom-up, dword-aligned rows.
    $w.Write((New-Object byte[] ($andStride * $Size)))
    $w.Flush()
    , $ms.ToArray()   # unary comma: see Get-PngBytes
}

$bmpSizes = 16, 20, 24, 32, 40, 48, 64
$entries = @()
foreach ($sz in $bmpSizes) {
    $entries += , @{ Size = $sz; Data = (Get-BmpIconEntryBytes (New-IconSource $sz) $sz) }
}
$entries += , @{ Size = 256; Data = (Get-PngBytes (New-IconSource 256)) }

$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$entries.Count)
$offset = 6 + 16 * $entries.Count
foreach ($e in $entries) {
    $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }
    $w.Write([byte]$dim); $w.Write([byte]$dim)
    $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([int16]1); $w.Write([int16]32)
    $w.Write([int32]$e.Data.Length); $w.Write([int32]$offset)
    $offset += $e.Data.Length
}
foreach ($e in $entries) { $w.Write([byte[]]$e.Data) }
$w.Flush()
[System.IO.File]::WriteAllBytes($OutPath, $out.ToArray())

# Prove the result loads through both consumers that matter.
Add-Type -AssemblyName System.Drawing
$probe = New-Object System.Drawing.Icon $OutPath
$probe.Dispose()
$wpfProbe = [System.Windows.Media.Imaging.BitmapFrame]::Create(
    (New-Object System.Uri $OutPath), 'None', 'OnLoad')
Write-Host ("OK: {0}  ({1:N0} bytes, {2} sizes: {3} + 256px PNG, WPF frame {4}x{5})" -f `
    $OutPath, (Get-Item $OutPath).Length, $entries.Count,
    ($bmpSizes -join '/'), $wpfProbe.PixelWidth, $wpfProbe.PixelHeight)
