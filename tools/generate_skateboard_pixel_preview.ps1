param(
    [string]$Preview = "boards/shields/nice_view_disp/widgets/skateboard_animation_preview_v10.png",
    [string]$Animation = "boards/shields/nice_view_disp/widgets/skateboard_animation_v10.gif",
    [string]$Output = "boards/shields/nice_view_disp/widgets/skateboard_art.c",
    [ValidateRange(5, 100)]
    [int]$FrameDelayCentiseconds = 25
)

Add-Type -AssemblyName System.Drawing

$frameWidth = 140
$frameHeight = 68
$centerY = 34
$scale = 4
$frames = @()

function New-Pen([float]$width) {
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::Black, $width)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $pen
}

function Project-Y([float]$localY, [float]$localZ, [double]$cosine, [double]$sine) {
    return [float]($centerY + ($localY * $cosine) - ($localZ * $sine))
}

function Draw-Flower([System.Drawing.Graphics]$graphics, [double]$cosine) {
    $flowerPen = New-Pen 1.4
    try {
        $points = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        for ($step = 0; $step -le 60; $step++) {
            $phi = (2.0 * [Math]::PI * $step) / 60.0
            $radius = 5.5 + (2.4 * [Math]::Cos(5.0 * $phi))
            $x = 70.0 + ($radius * [Math]::Cos($phi))
            $localY = $radius * [Math]::Sin($phi)
            $points.Add([System.Drawing.PointF]::new([float]$x,
                                                     (Project-Y $localY 0 $cosine 0)))
        }
        $graphics.DrawLines($flowerPen, $points.ToArray())
        $centerHeight = [Math]::Max(2.0, 4.0 * [Math]::Abs($cosine))
        $graphics.DrawEllipse($flowerPen, [float]68.0,
                              [float]($centerY - ($centerHeight / 2.0)),
                              [float]4.0, [float]$centerHeight)
    } finally {
        $flowerPen.Dispose()
    }
}

function Draw-GripPattern([System.Drawing.Graphics]$graphics, [double]$cosine) {
    $patternPen = New-Pen 1.1
    try {
        # A repeating 4x4 Bayer matrix creates a regular grip-tape tone. The
        # three-quarter views use one fewer level because transverse source rows
        # compress onto fewer display pixels.
        $bayer4 = @(0, 8, 2, 10,
                    12, 4, 14, 6,
                    3, 11, 1, 9,
                    15, 7, 13, 5)
        $dotThreshold = if ([Math]::Abs($cosine) -gt 0.85) { 6 } else { 5 }
        for ($x = 38; $x -le 102; $x++) {
            for ($localY = -9; $localY -le 9; $localY++) {
                $matrixX = $x % 4
                $matrixY = ($localY + 12) % 4
                if ($bayer4[($matrixY * 4) + $matrixX] -lt $dotThreshold) {
                    $screenY = [int][Math]::Round((Project-Y $localY 0 $cosine 0))
                    $graphics.FillRectangle([System.Drawing.Brushes]::Black, $x, $screenY, 1, 1)
                }
            }
        }

        foreach ($side in @(-1, 1)) {
            $localY = 4.5 * $side
            $points = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(34, (Project-Y $localY 0 $cosine 0)),
                [System.Drawing.PointF]::new(61, (Project-Y $localY 0 $cosine 0)),
                [System.Drawing.PointF]::new(66, (Project-Y (7.0 * $side) 0 $cosine 0)),
                [System.Drawing.PointF]::new(74, (Project-Y (7.0 * $side) 0 $cosine 0)),
                [System.Drawing.PointF]::new(79, (Project-Y $localY 0 $cosine 0)),
                [System.Drawing.PointF]::new(106, (Project-Y $localY 0 $cosine 0))
            )
            $graphics.DrawLines($patternPen, $points)
        }
        $diamond = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new(63, (Project-Y 0 0 $cosine 0)),
            [System.Drawing.PointF]::new(70, (Project-Y -7 0 $cosine 0)),
            [System.Drawing.PointF]::new(77, (Project-Y 0 0 $cosine 0)),
            [System.Drawing.PointF]::new(70, (Project-Y 7 0 $cosine 0)),
            [System.Drawing.PointF]::new(63, (Project-Y 0 0 $cosine 0))
        )
        $graphics.DrawLines($patternPen, $diamond)
    } finally {
        $patternPen.Dispose()
    }
}

function Draw-WheelCylinder([System.Drawing.Graphics]$graphics, [float]$truckX,
                            [int]$side, [double]$cosine, [double]$sine,
                            [System.Drawing.Pen]$wheelPen,
                            [System.Drawing.Pen]$detailPen) {
    # The wheel axle runs across the deck. Its two circular faces separate as that
    # axle turns broadside to the viewer, revealing a five-pixel sidewall.
    $innerY = Project-Y (14 * $side) 4 $cosine $sine
    $outerY = Project-Y (19 * $side) 4 $cosine $sine
    $wheelDiameter = 12.0
    $wheelRadius = $wheelDiameter / 2.0
    $faceHeight = [float](5.0 + (7.0 * [Math]::Abs($sine)))
    $halfFaceHeight = $faceHeight / 2.0
    $bodyTop = [float]([Math]::Min($innerY, $outerY) - $halfFaceHeight)
    $bodyBottom = [float]([Math]::Max($innerY, $outerY) + $halfFaceHeight)

    $graphics.FillRectangle([System.Drawing.Brushes]::White,
                            [float]($truckX - $wheelRadius), $bodyTop, $wheelDiameter,
                            [float]($bodyBottom - $bodyTop))
    $graphics.DrawLine($wheelPen, [float]($truckX - $wheelRadius), $innerY,
                       [float]($truckX - $wheelRadius), $outerY)
    $graphics.DrawLine($wheelPen, [float]($truckX + $wheelRadius), $innerY,
                       [float]($truckX + $wheelRadius), $outerY)

    # Both rims stay visible in three-quarter views; the outer face carries the hub.
    $graphics.DrawEllipse($detailPen,
                          [float]($truckX - $wheelRadius),
                          [float]($innerY - $halfFaceHeight),
                          $wheelDiameter, $faceHeight)
    $graphics.DrawEllipse($wheelPen,
                          [float]($truckX - $wheelRadius),
                          [float]($outerY - $halfFaceHeight),
                          $wheelDiameter, $faceHeight)
    if ($faceHeight -ge 5) {
        $hubHeight = [float][Math]::Max(2, $faceHeight - 5)
        $graphics.DrawEllipse($detailPen,
                              [float]($truckX - 2),
                              [float]($outerY - ($hubHeight / 2)),
                              4, $hubHeight)
    }
}

function Draw-TruckAssembly([System.Drawing.Graphics]$graphics, [float]$truckX,
                            [double]$cosine, [double]$sine,
                            [System.Drawing.Pen]$truckPen,
                            [System.Drawing.Pen]$detailPen) {
    $direction = if ($truckX -lt 70) { 1 } else { -1 }
    $mountX = $truckX + ($direction * 5)

    # A solid axle beam spans the inner wheel faces. Its depth keeps it visible
    # when that span collapses in the two full side-profile frames.
    $axleEnds = @(
        (Project-Y -14 4 $cosine $sine),
        (Project-Y 14 4 $cosine $sine)
    )
    $axleTop = [float]([Math]::Min($axleEnds[0], $axleEnds[1]) - 1.5)
    $axleBottom = [float]([Math]::Max($axleEnds[0], $axleEnds[1]) + 1.5)
    $graphics.FillRectangle([System.Drawing.Brushes]::Black,
                            [float]($truckX - 2), $axleTop, 4,
                            [float]($axleBottom - $axleTop))

    # The broad tapered hanger connects the axle to an inboard baseplate. The
    # lower pivot depth creates a triangular truck silhouette in side view.
    $outerYs = @(
        (Project-Y -7 4 $cosine $sine),
        (Project-Y 7 4 $cosine $sine)
    )
    $innerYs = @(
        (Project-Y -3 1.5 $cosine $sine),
        (Project-Y 3 1.5 $cosine $sine)
    )
    $topOuter = [Math]::Min($outerYs[0], $outerYs[1])
    $bottomOuter = [Math]::Max($outerYs[0], $outerYs[1])
    $topInner = [Math]::Min($innerYs[0], $innerYs[1])
    $bottomInner = [Math]::Max($innerYs[0], $innerYs[1])
    $hanger = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new([float]($mountX - 2.5), [float]$topInner),
        [System.Drawing.PointF]::new([float]($truckX - 4), [float]$topOuter),
        [System.Drawing.PointF]::new([float]($truckX + 4), [float]$topOuter),
        [System.Drawing.PointF]::new([float]($mountX + 2.5), [float]$topInner),
        [System.Drawing.PointF]::new([float]($mountX + 2.5), [float]$bottomInner),
        [System.Drawing.PointF]::new([float]($truckX + 4), [float]$bottomOuter),
        [System.Drawing.PointF]::new([float]($truckX - 4), [float]$bottomOuter),
        [System.Drawing.PointF]::new([float]($mountX - 2.5), [float]$bottomInner)
    )
    $graphics.FillPolygon([System.Drawing.Brushes]::White, $hanger)
    $graphics.DrawPolygon($truckPen, $hanger)

    # The drop-through mounting plate remains broad enough to read as a plate,
    # rather than as the small floating square used in the earlier previews.
    $mountYs = @(
        (Project-Y -3.5 4 $cosine $sine),
        (Project-Y 3.5 4 $cosine $sine)
    )
    $mountTop = [float]([Math]::Min($mountYs[0], $mountYs[1]) - 0.8)
    $mountBottom = [float]([Math]::Max($mountYs[0], $mountYs[1]) + 0.8)
    $graphics.FillRectangle([System.Drawing.Brushes]::White,
                            [float]($mountX - 3.5), $mountTop, 7,
                            [float]($mountBottom - $mountTop))
    $graphics.DrawRectangle($truckPen,
                            [float]($mountX - 3.5), $mountTop, 7,
                            [float]($mountBottom - $mountTop))

    foreach ($side in @(-1, 1)) {
        $graphics.DrawLine($truckPen,
                           $truckX, (Project-Y (11 * $side) 4 $cosine $sine),
                           $mountX, (Project-Y (3 * $side) 1.5 $cosine $sine))
    }

    $pivotX = [float](($truckX + $mountX) / 2.0)
    $pivotY = Project-Y 0 1.5 $cosine $sine
    $graphics.FillEllipse([System.Drawing.Brushes]::Black,
                          [float]($pivotX - 1.5), [float]($pivotY - 1.5), 3, 3)
    $graphics.DrawLine($detailPen, $mountX, (Project-Y 0 4 $cosine $sine),
                       $pivotX, $pivotY)
}

function New-SkateboardFrame([int]$index) {
    $angle = (2.0 * [Math]::PI * $index) / 8.0
    $cosine = [Math]::Cos($angle)
    $sine = [Math]::Sin($angle)
    $bitmap = [System.Drawing.Bitmap]::new($frameWidth, $frameHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $outlinePen = New-Pen 1.8
    $detailPen = New-Pen 1.0
    $truckPen = New-Pen 1.6
    $wheelPen = New-Pen 1.6
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        # The Superdupersonic is a double-drop deck: the truck platforms pass
        # through at axle height, short ramps lower the standing platform, and
        # the outer nose/tail wedges angle back down toward the ground.
        $profileX = @(14, 25, 31, 37, 103, 109, 115, 126)
        $profileHalfWidth = @(7, 7, 10, 12, 12, 10, 7, 7)
        $profileZ = @(1, 4, 3, 0, 0, 3, 4, 1)
        $deckPoints = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        for ($i = 0; $i -lt $profileX.Count; $i++) {
            $halfHeight = [Math]::Abs($profileHalfWidth[$i] * $cosine) +
                          [Math]::Abs(1.3 * $sine)
            $deckCenterY = Project-Y 0 $profileZ[$i] $cosine $sine
            $deckPoints.Add([System.Drawing.PointF]::new($profileX[$i],
                                                         [float]($deckCenterY - $halfHeight)))
        }
        for ($i = $profileX.Count - 1; $i -ge 0; $i--) {
            $halfHeight = [Math]::Abs($profileHalfWidth[$i] * $cosine) +
                          [Math]::Abs(1.3 * $sine)
            $deckCenterY = Project-Y 0 $profileZ[$i] $cosine $sine
            $deckPoints.Add([System.Drawing.PointF]::new($profileX[$i],
                                                         [float]($deckCenterY + $halfHeight)))
        }
        $graphics.FillPolygon([System.Drawing.Brushes]::White, $deckPoints.ToArray())
        $graphics.DrawPolygon($outlinePen, $deckPoints.ToArray())

        if ([Math]::Abs($cosine) -gt 0.32) {
            if ($cosine -gt 0) {
                Draw-Flower $graphics $cosine
            } else {
                Draw-GripPattern $graphics $cosine
            }
        } else {
            $sideProfile = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
            for ($i = 0; $i -lt $profileX.Count; $i++) {
                $sideProfile.Add([System.Drawing.PointF]::new(
                    $profileX[$i], (Project-Y 0 $profileZ[$i] $cosine $sine)))
            }
            $graphics.DrawLines($detailPen, $sideProfile.ToArray())
        }

        foreach ($truckX in @(24, 116)) {
            Draw-TruckAssembly $graphics $truckX $cosine $sine $truckPen $detailPen
            foreach ($side in @(-1, 1)) {
                Draw-WheelCylinder $graphics $truckX $side $cosine $sine $wheelPen $detailPen
            }
        }
    } finally {
        $wheelPen.Dispose()
        $truckPen.Dispose()
        $detailPen.Dispose()
        $outlinePen.Dispose()
        $graphics.Dispose()
    }
    return $bitmap
}

function Write-U16([System.IO.BinaryWriter]$writer, [int]$value) {
    $writer.Write([byte]($value -band 0xff))
    $writer.Write([byte](($value -shr 8) -band 0xff))
}

function Write-ByteValues([System.IO.BinaryWriter]$writer, [int[]]$values) {
    foreach ($value in $values) { $writer.Write([byte]$value) }
}

function Write-LzwPixels([System.IO.BinaryWriter]$writer,
                          [System.Collections.Generic.List[byte]]$pixels) {
    $writer.Write([byte]2)
    $packed = [System.Collections.Generic.List[byte]]::new()
    $bitBuffer = 0
    $bitCount = 0
    foreach ($pixel in $pixels) {
        foreach ($code in @(4, [int]$pixel)) {
            $bitBuffer = $bitBuffer -bor ($code -shl $bitCount)
            $bitCount += 3
            while ($bitCount -ge 8) {
                $packed.Add([byte]($bitBuffer -band 0xff))
                $bitBuffer = $bitBuffer -shr 8
                $bitCount -= 8
            }
        }
    }
    $bitBuffer = $bitBuffer -bor (5 -shl $bitCount)
    $bitCount += 3
    while ($bitCount -gt 0) {
        $packed.Add([byte]($bitBuffer -band 0xff))
        $bitBuffer = $bitBuffer -shr 8
        $bitCount -= 8
    }
    for ($offset = 0; $offset -lt $packed.Count; $offset += 255) {
        $count = [Math]::Min(255, $packed.Count - $offset)
        $writer.Write([byte]$count)
        $writer.Write($packed.GetRange($offset, $count).ToArray())
    }
    $writer.Write([byte]0)
}

function Get-FrameBytes([System.Drawing.Bitmap]$frame, [bool]$rotate180) {
    $bytes = [System.Collections.Generic.List[byte]]::new(1224)
    for ($y = 0; $y -lt $frameHeight; $y++) {
        for ($byteX = 0; $byteX -lt 18; $byteX++) {
            $value = 0
            for ($bit = 0; $bit -lt 8; $bit++) {
                $x = ($byteX * 8) + $bit
                $isWhite = $true
                if ($x -lt $frameWidth) {
                    $sampleX = if ($rotate180) { $frameWidth - 1 - $x } else { $x }
                    $sampleY = if ($rotate180) { $frameHeight - 1 - $y } else { $y }
                    $isWhite = $frame.GetPixel($sampleX, $sampleY).R -gt 127
                }
                if ($isWhite) {
                    $value = $value -bor (1 -shl (7 - $bit))
                }
            }
            $bytes.Add([byte]$value)
        }
    }
    return $bytes.ToArray()
}

function Add-CByteRows([System.Collections.Generic.List[string]]$lines, [byte[]]$bytes) {
    for ($offset = 0; $offset -lt $bytes.Count; $offset += 18) {
        $end = [Math]::Min($offset + 17, $bytes.Count - 1)
        $chunk = $bytes[$offset..$end] | ForEach-Object { "0x{0:x2}" -f $_ }
        $lines.Add("    " + ($chunk -join ", ") + ",")
    }
}

function Write-LvglSource([System.Drawing.Bitmap[]]$sourceFrames, [string]$path) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("/* Generated by tools/generate_skateboard_pixel_preview.ps1. */")
    $lines.Add("#include <stddef.h>")
    $lines.Add("#include <lvgl.h>")
    $lines.Add("")
    $lines.Add("#ifndef LV_ATTRIBUTE_MEM_ALIGN")
    $lines.Add("#define LV_ATTRIBUTE_MEM_ALIGN")
    $lines.Add("#endif")
    $lines.Add("")

    for ($index = 0; $index -lt $sourceFrames.Count; $index++) {
        $normal = Get-FrameBytes $sourceFrames[$index] $false
        $rotated = Get-FrameBytes $sourceFrames[$index] $true
        $lines.Add("static const LV_ATTRIBUTE_MEM_ALIGN LV_ATTRIBUTE_LARGE_CONST uint8_t skateboard_frame_${index}_map[] = {")
        $lines.Add("#if CONFIG_NICE_VIEW_DISP_WIDGET_INVERTED")
        $lines.Add("    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0xff,")
        $lines.Add("#else")
        $lines.Add("    0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff,")
        $lines.Add("#endif")
        $lines.Add("#ifdef CONFIG_NICE_VIEW_DISP_ROTATE_180")
        Add-CByteRows $lines $rotated
        $lines.Add("#else")
        Add-CByteRows $lines $normal
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
    for ($index = 0; $index -lt $sourceFrames.Count; $index++) {
        $lines.Add("    &skateboard_frame_${index},")
    }
    $lines.Add("};")
    $lines.Add("")
    $lines.Add("const size_t skateboard_frame_count = sizeof(skateboard_frames) / sizeof(skateboard_frames[0]);")
    [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $path), $lines)
}

try {
    for ($index = 0; $index -lt 8; $index++) {
        $frames += New-SkateboardFrame $index
    }

    $previewBitmap = [System.Drawing.Bitmap]::new($frameWidth * 4, $frameHeight * 2)
    $previewGraphics = [System.Drawing.Graphics]::FromImage($previewBitmap)
    try {
        $previewGraphics.Clear([System.Drawing.Color]::White)
        for ($index = 0; $index -lt 8; $index++) {
            $x = ($index % 4) * $frameWidth
            $y = [int][Math]::Floor($index / 4) * $frameHeight
            $previewGraphics.DrawImageUnscaled($frames[$index], $x, $y)
        }
        $previewBitmap.Save((Join-Path (Get-Location) $Preview),
                            [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $previewGraphics.Dispose()
        $previewBitmap.Dispose()
    }

    $gifWidth = $frameWidth * $scale
    $gifHeight = $frameHeight * $scale
    $stream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("GIF89a"))
        Write-U16 $writer $gifWidth
        Write-U16 $writer $gifHeight
        Write-ByteValues $writer @(0x80, 0x01, 0x00)
        Write-ByteValues $writer @(0x00, 0x00, 0x00, 0xff, 0xff, 0xff)
        Write-ByteValues $writer @(0x21, 0xff, 0x0b)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("NETSCAPE2.0"))
        Write-ByteValues $writer @(0x03, 0x01, 0x00, 0x00, 0x00)
        for ($index = 0; $index -lt 8; $index++) {
            Write-ByteValues $writer @(0x21, 0xf9, 0x04, 0x04,
                                       ($FrameDelayCentiseconds -band 0xff),
                                       (($FrameDelayCentiseconds -shr 8) -band 0xff), 0x00, 0x00)
            $writer.Write([byte]0x2c)
            Write-U16 $writer 0
            Write-U16 $writer 0
            Write-U16 $writer $gifWidth
            Write-U16 $writer $gifHeight
            $writer.Write([byte]0x00)
            $pixels = [System.Collections.Generic.List[byte]]::new($gifWidth * $gifHeight)
            for ($y = 0; $y -lt $frameHeight; $y++) {
                for ($repeatY = 0; $repeatY -lt $scale; $repeatY++) {
                    for ($x = 0; $x -lt $frameWidth; $x++) {
                        $color = $frames[$index].GetPixel($x, $y)
                        $pixel = if ($color.R -gt 127) { [byte]1 } else { [byte]0 }
                        for ($repeatX = 0; $repeatX -lt $scale; $repeatX++) {
                            $pixels.Add($pixel)
                        }
                    }
                }
            }
            Write-LzwPixels $writer $pixels
        }
        $writer.Write([byte]0x3b)
        [System.IO.File]::WriteAllBytes((Join-Path (Get-Location) $Animation),
                                        $stream.ToArray())
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }

    Write-LvglSource $frames $Output
} finally {
    foreach ($frame in $frames) { $frame.Dispose() }
}
