param(
    [string]$Source = "boards/shields/nice_view_disp/widgets/skateboard_turntable_source.png",
    [string]$Output = "boards/shields/nice_view_disp/widgets/skateboard_art.c",
    [string]$Preview = "boards/shields/nice_view_disp/widgets/skateboard_animation_preview.png",
    [ValidateRange(0, 255)]
    [int]$Threshold = 160,
    [ValidateRange(0, 16)]
    [int]$DitherStrength = 0
)

Add-Type -AssemblyName System.Drawing

$frameCount = 8
$displayWidth = 140
$displayHeight = 68
$margin = 3
$bayer = @(0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)
$sourceBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Source))
$frames = @()

function Get-PixelBytes([System.Drawing.Bitmap]$bitmap, [bool]$rotate180) {
    $bytes = [System.Collections.Generic.List[byte]]::new()
    for ($y = 0; $y -lt $displayHeight; $y++) {
        for ($byteX = 0; $byteX -lt 18; $byteX++) {
            $value = 0
            for ($bit = 0; $bit -lt 8; $bit++) {
                $x = ($byteX * 8) + $bit
                $white = $true
                if ($x -lt $displayWidth) {
                    $sampleX = if ($rotate180) { $displayWidth - 1 - $x } else { $x }
                    $sampleY = if ($rotate180) { $displayHeight - 1 - $y } else { $y }
                    $color = $bitmap.GetPixel($sampleX, $sampleY)
                    $gray = [int](0.299 * $color.R + 0.587 * $color.G + 0.114 * $color.B)
                    $pixelThreshold = $Threshold
                    if ($DitherStrength -gt 0) {
                        $pixelThreshold += (($bayer[(($sampleY % 4) * 4) + ($sampleX % 4)] - 7.5) *
                                            $DitherStrength)
                    }
                    $white = $gray -gt $pixelThreshold
                }
                if ($white) { $value = $value -bor (1 -shl (7 - $bit)) }
            }
            $bytes.Add([byte]$value)
        }
    }
    return $bytes
}

try {
    $cellWidth = [int]($sourceBitmap.Width / $frameCount)
    for ($index = 0; $index -lt $frameCount; $index++) {
        $left = $index * $cellWidth
        $right = [Math]::Min($sourceBitmap.Width, $left + $cellWidth)
        $minX = $right
        $minY = $sourceBitmap.Height
        $maxX = $left
        $maxY = 0

        for ($y = 0; $y -lt $sourceBitmap.Height; $y += 2) {
            for ($x = $left; $x -lt $right; $x += 2) {
                $pixel = $sourceBitmap.GetPixel($x, $y)
                if (($pixel.R + $pixel.G + $pixel.B) -lt 735) {
                    $minX = [Math]::Min($minX, $x)
                    $maxX = [Math]::Max($maxX, $x)
                    $minY = [Math]::Min($minY, $y)
                    $maxY = [Math]::Max($maxY, $y)
                }
            }
        }

        $padding = 4
        $minX = [Math]::Max($left, $minX - $padding)
        $maxX = [Math]::Min($right - 1, $maxX + $padding)
        $minY = [Math]::Max(0, $minY - $padding)
        $maxY = [Math]::Min($sourceBitmap.Height - 1, $maxY + $padding)
        $cropWidth = $maxX - $minX + 1
        $cropHeight = $maxY - $minY + 1

        # Rotate the portrait product views so the board fills the wide nice!view art area.
        $rotatedWidth = $cropHeight
        $rotatedHeight = $cropWidth
        $scale = [Math]::Min(($displayWidth - 2 * $margin) / $rotatedWidth,
                             ($displayHeight - 2 * $margin) / $rotatedHeight)
        $drawWidth = [Math]::Max(1, [int][Math]::Round($rotatedWidth * $scale))
        $drawHeight = [Math]::Max(1, [int][Math]::Round($rotatedHeight * $scale))
        $frame = [System.Drawing.Bitmap]::new($displayWidth, $displayHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($frame)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.TranslateTransform($displayWidth / 2, $displayHeight / 2)
            $graphics.RotateTransform(90)
            $destination = [System.Drawing.Rectangle]::new(
                [int](-$drawHeight / 2), [int](-$drawWidth / 2), $drawHeight, $drawWidth)
            $sourceRect = [System.Drawing.Rectangle]::new($minX, $minY, $cropWidth, $cropHeight)
            $graphics.DrawImage($sourceBitmap, $destination, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
            $graphics.ResetTransform()
        } finally {
            $graphics.Dispose()
        }
        $frames += $frame
    }

    $previewBitmap = [System.Drawing.Bitmap]::new($displayWidth * 4, $displayHeight * 2)
    try {
        for ($index = 0; $index -lt $frameCount; $index++) {
            $previewBytes = Get-PixelBytes $frames[$index] $false
            $originX = ($index % 4) * $displayWidth
            $originY = [int][Math]::Floor($index / 4) * $displayHeight
            for ($y = 0; $y -lt $displayHeight; $y++) {
                for ($x = 0; $x -lt $displayWidth; $x++) {
                    $byte = $previewBytes[($y * 18) + [int]($x / 8)]
                    $isWhite = ($byte -band (1 -shl (7 - ($x % 8)))) -ne 0
                    $previewBitmap.SetPixel($originX + $x, $originY + $y,
                        $(if ($isWhite) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }))
                }
            }
        }
        $previewBitmap.Save((Join-Path (Get-Location) $Preview), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $previewBitmap.Dispose()
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("/* Generated by tools/generate_skateboard_art.ps1. */")
    $lines.Add("#include <stddef.h>")
    $lines.Add("#include <lvgl.h>")
    $lines.Add("")
    $lines.Add("#ifndef LV_ATTRIBUTE_MEM_ALIGN")
    $lines.Add("#define LV_ATTRIBUTE_MEM_ALIGN")
    $lines.Add("#endif")
    $lines.Add("")

    for ($index = 0; $index -lt $frameCount; $index++) {
        $normal = Get-PixelBytes $frames[$index] $false
        $rotated = Get-PixelBytes $frames[$index] $true
        $lines.Add("static const LV_ATTRIBUTE_MEM_ALIGN LV_ATTRIBUTE_LARGE_CONST uint8_t skateboard_frame_${index}_map[] = {")
        $lines.Add("#if CONFIG_NICE_VIEW_DISP_WIDGET_INVERTED")
        $lines.Add("    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0xff,")
        $lines.Add("#else")
        $lines.Add("    0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff,")
        $lines.Add("#endif")
        $lines.Add("#ifdef CONFIG_NICE_VIEW_DISP_ROTATE_180")
        for ($offset = 0; $offset -lt $rotated.Count; $offset += 18) {
            $chunk = $rotated[$offset..([Math]::Min($offset + 17, $rotated.Count - 1))] | ForEach-Object { "0x{0:x2}" -f $_ }
            $lines.Add("    " + ($chunk -join ", ") + ",")
        }
        $lines.Add("#else")
        for ($offset = 0; $offset -lt $normal.Count; $offset += 18) {
            $chunk = $normal[$offset..([Math]::Min($offset + 17, $normal.Count - 1))] | ForEach-Object { "0x{0:x2}" -f $_ }
            $lines.Add("    " + ($chunk -join ", ") + ",")
        }
        $lines.Add("#endif")
        $lines.Add("};")
        $lines.Add("")
        $lines.Add("static const lv_img_dsc_t skateboard_frame_${index} = {")
        $lines.Add("    .header.cf = LV_COLOR_FORMAT_I1,")
        $lines.Add("    .header.w = 140,")
        $lines.Add("    .header.h = 68,")
        $lines.Add("    .data_size = 1232,")
        $lines.Add("    .data = skateboard_frame_${index}_map,")
        $lines.Add("};")
        $lines.Add("")
    }

    $lines.Add("const lv_img_dsc_t *const skateboard_frames[] = {")
    for ($index = 0; $index -lt $frameCount; $index++) {
        $lines.Add("    &skateboard_frame_${index},")
    }
    $lines.Add("};")
    $lines.Add("")
    $lines.Add("const size_t skateboard_frame_count = sizeof(skateboard_frames) / sizeof(skateboard_frames[0]);")
    [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $Output), $lines)
} finally {
    foreach ($frame in $frames) { $frame.Dispose() }
    $sourceBitmap.Dispose()
}
