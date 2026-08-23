param(
    [string]$Preview = "boards/shields/nice_view_disp/widgets/skateboard_animation_preview_v4.png",
    [string]$Animation = "boards/shields/nice_view_disp/widgets/skateboard_animation_v4.gif",
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
    $faceHeight = [float](4.0 + (6.0 * [Math]::Abs($sine)))
    $halfFaceHeight = $faceHeight / 2.0
    $bodyTop = [float]([Math]::Min($innerY, $outerY) - $halfFaceHeight)
    $bodyBottom = [float]([Math]::Max($innerY, $outerY) + $halfFaceHeight)

    $graphics.FillRectangle([System.Drawing.Brushes]::White,
                            [float]($truckX - 5), $bodyTop, 10,
                            [float]($bodyBottom - $bodyTop))
    $graphics.DrawLine($wheelPen, [float]($truckX - 5), $innerY,
                       [float]($truckX - 5), $outerY)
    $graphics.DrawLine($wheelPen, [float]($truckX + 5), $innerY,
                       [float]($truckX + 5), $outerY)

    # Both rims stay visible in three-quarter views; the outer face carries the hub.
    $graphics.DrawEllipse($detailPen,
                          [float]($truckX - 5), [float]($innerY - $halfFaceHeight),
                          10, $faceHeight)
    $graphics.DrawEllipse($wheelPen,
                          [float]($truckX - 5), [float]($outerY - $halfFaceHeight),
                          10, $faceHeight)
    if ($faceHeight -ge 5) {
        $hubHeight = [float][Math]::Max(2, $faceHeight - 5)
        $graphics.DrawEllipse($detailPen,
                              [float]($truckX - 2),
                              [float]($outerY - ($hubHeight / 2)),
                              4, $hubHeight)
    }
}

function New-SkateboardFrame([int]$index) {
    $angle = (2.0 * [Math]::PI * $index) / 8.0
    $cosine = [Math]::Cos($angle)
    $sine = [Math]::Sin($angle)
    $bitmap = [System.Drawing.Bitmap]::new($frameWidth, $frameHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $outlinePen = New-Pen 1.8
    $detailPen = New-Pen 1.0
    $truckPen = New-Pen 1.3
    $wheelPen = New-Pen 1.6
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $profileX = @(14, 25, 31, 109, 115, 126)
        $profileHalfWidth = @(7, 7, 12, 12, 7, 7)
        $deckPoints = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
        for ($i = 0; $i -lt $profileX.Count; $i++) {
            $halfHeight = [Math]::Abs($profileHalfWidth[$i] * $cosine) +
                          [Math]::Abs(1.8 * $sine)
            $deckPoints.Add([System.Drawing.PointF]::new($profileX[$i],
                                                         [float]($centerY - $halfHeight)))
        }
        for ($i = $profileX.Count - 1; $i -ge 0; $i--) {
            $halfHeight = [Math]::Abs($profileHalfWidth[$i] * $cosine) +
                          [Math]::Abs(1.8 * $sine)
            $deckPoints.Add([System.Drawing.PointF]::new($profileX[$i],
                                                         [float]($centerY + $halfHeight)))
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
            $graphics.DrawLine($detailPen, 31, $centerY, 109, $centerY)
        }

        foreach ($truckX in @(24, 116)) {
            $innerWheelYs = @(
                (Project-Y -14 4 $cosine $sine),
                (Project-Y 14 4 $cosine $sine)
            )
            $graphics.DrawLine($truckPen, $truckX, $innerWheelYs[0],
                               $truckX, $innerWheelYs[1])
            $truckCenter = ($innerWheelYs[0] + $innerWheelYs[1]) / 2.0
            $graphics.FillRectangle([System.Drawing.Brushes]::White,
                                    [float]($truckX - 3), [float]($truckCenter - 2), 6, 4)
            $graphics.DrawRectangle($truckPen,
                                    [float]($truckX - 3), [float]($truckCenter - 2), 6, 4)
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
} finally {
    foreach ($frame in $frames) { $frame.Dispose() }
}
