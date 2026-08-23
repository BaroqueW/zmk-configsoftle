param(
    [string]$Preview = "boards/shields/nice_view_disp/widgets/skateboard_animation_preview_v10.png",
    [string]$Animation = "boards/shields/nice_view_disp/widgets/skateboard_animation_v10.gif",
    [string]$Output = "boards/shields/nice_view_disp/widgets/skateboard_art.c",
    [ValidateRange(5, 100)]
    [int]$FrameDelayCentiseconds = 25
)

$ErrorActionPreference = "Stop"
$renderer = Join-Path $PSScriptRoot "generate_skateboard_pixel_preview.ps1"

& $renderer `
    -Preview $Preview `
    -Animation $Animation `
    -Output $Output `
    -FrameDelayCentiseconds $FrameDelayCentiseconds
