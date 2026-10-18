# Rebuild the documentation palette from design-tokens.json. No app files change.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $projectRoot 'docs\ui设计手册\assets'
$tokens = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $assetRoot 'design-tokens.json') | ConvertFrom-Json
$entries = @($tokens.colors.PSObject.Properties)
$width = 1200
$margin = 40
$columnGap = 24
$cardWidth = 357
$cardHeight = 172
$rowGap = 20
$top = 154
$rows = [int][Math]::Ceiling($entries.Count / 3.0)
$height = $top + $rows * ($cardHeight + $rowGap) - $rowGap + 48
$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$resources = [System.Collections.Generic.List[System.IDisposable]]::new()

function New-PaletteBrush([string]$hex) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($hex))
    $resources.Add($brush)
    return $brush
}

try {
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($tokens.colors.background.hex))
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $fontFamily = 'Microsoft YaHei UI'
    $titleFont = [System.Drawing.Font]::new($fontFamily, 36, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $labelFont = [System.Drawing.Font]::new($fontFamily, 21, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $smallFont = [System.Drawing.Font]::new($fontFamily, 16, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $codeFont = [System.Drawing.Font]::new('Consolas', 18, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    foreach ($font in @($titleFont, $labelFont, $smallFont, $codeFont)) { $resources.Add($font) }
    $ink = New-PaletteBrush $tokens.colors.textPrimary.hex
    $muted = New-PaletteBrush $tokens.colors.textSecondary.hex
    $white = New-PaletteBrush $tokens.colors.surface.hex
    $border = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($tokens.colors.divider.hex), 1)
    $resources.Add($border)
    $graphics.DrawString('Mission Book 颜色速查', $titleFont, $ink, [single]$margin, [single]30)
    $graphics.DrawString('统一UI · 当前配色 · 与 design-tokens.json 同步', $smallFont, $muted, [single]$margin, [single]88)
    $graphics.DrawString('色值以 design-tokens.json 与颜色文档为准，不从原型截图取色。', $smallFont, $muted, [single]$margin, [single]114)

    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        $color = $entry.Value
        $column = $index % 3
        $row = [int][Math]::Floor($index / 3.0)
        $x = $margin + $column * ($cardWidth + $columnGap)
        $y = $top + $row * ($cardHeight + $rowGap)
        $graphics.FillRectangle($white, [int]$x, [int]$y, $cardWidth, $cardHeight)
        $graphics.DrawRectangle($border, [int]$x, [int]$y, $cardWidth, $cardHeight)
        $swatch = New-PaletteBrush $color.hex
        $graphics.FillRectangle($swatch, [int]($x + 16), [int]($y + 16), ($cardWidth - 32), 58)
        $graphics.DrawRectangle($border, [int]($x + 16), [int]($y + 16), ($cardWidth - 32), 58)
        $graphics.DrawString($color.label, $labelFont, $ink, [single]($x + 16), [single]($y + 82))
        $graphics.DrawString(($entry.Name + '  ' + $color.hex), $codeFont, $ink, [single]($x + 16), [single]($y + 115))
        $status = '当前配色'
        $graphics.DrawString($status, $smallFont, $muted, [single]($x + 16), [single]($y + 143))
    }
    $outputPath = Join-Path $assetRoot '颜色速查.png'
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Palette generated: $($entries.Count) colors, ${width}x${height}."
}
finally {
    foreach ($resource in $resources) { $resource.Dispose() }
    $graphics.Dispose()
    $bitmap.Dispose()
}
