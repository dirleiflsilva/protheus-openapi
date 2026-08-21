param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function ConvertFrom-YamlKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $result = $Value.Trim()
    if ($result.Length -ge 2 -and $result[0] -eq "'" -and $result[$result.Length - 1] -eq "'") {
        return $result.Substring(1, $result.Length - 2).Replace("''", "'")
    }

    if ($result.Length -ge 2 -and $result[0] -eq '"' -and $result[$result.Length - 1] -eq '"') {
        return $result.Substring(1, $result.Length - 2)
    }

    return $result
}

function Get-YamlKeyEntry {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    $match = [regex]::Match(
        $Line,
        '^(?<spaces> *)(?<key>''[^'']*''|"[^"]*"|[^:#][^:]*?):[ ]*(?<value>.*)$'
    )
    if (-not $match.Success) {
        return $null
    }

    return [PSCustomObject]@{
        Key = ConvertFrom-YamlKey -Value $match.Groups["key"].Value
        Indent = $match.Groups["spaces"].Value.Length
        Line = $LineNumber
        Value = $match.Groups["value"].Value
    }
}

function Get-BlockChildren {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [int]$Start,

        [Parameter(Mandatory = $true)]
        [int]$End
    )

    $starts = @()
    for ($index = $Start + 1; $index -le $End; $index++) {
        $entry = Get-YamlKeyEntry -Line $Lines[$index] -LineNumber ($index + 1)
        if ($null -ne $entry -and $entry.Indent -eq 4) {
            $starts += $index
        }
    }

    $children = @()
    for ($childIndex = 0; $childIndex -lt $starts.Count; $childIndex++) {
        $childStart = $starts[$childIndex]
        $childEnd = $End
        if ($childIndex + 1 -lt $starts.Count) {
            $childEnd = $starts[$childIndex + 1] - 1
        }

        $entry = Get-YamlKeyEntry -Line $Lines[$childStart] -LineNumber ($childStart + 1)
        $children += [PSCustomObject]@{
            Key = $entry.Key
            Line = $entry.Line
            Lines = [string[]]$Lines[$childStart..$childEnd]
        }
    }

    return @($children)
}

function Get-PathBlocks {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [int]$PathsStart,

        [Parameter(Mandatory = $true)]
        [int]$PathsEnd
    )

    $starts = @()
    for ($index = $PathsStart + 1; $index -le $PathsEnd; $index++) {
        $entry = Get-YamlKeyEntry -Line $Lines[$index] -LineNumber ($index + 1)
        if ($null -ne $entry -and $entry.Indent -eq 2) {
            $starts += $index
        }
    }

    $blocks = @()
    for ($pathIndex = 0; $pathIndex -lt $starts.Count; $pathIndex++) {
        $pathStart = $starts[$pathIndex]
        $pathEnd = $PathsEnd
        if ($pathIndex + 1 -lt $starts.Count) {
            $pathEnd = $starts[$pathIndex + 1] - 1
        }

        $entry = Get-YamlKeyEntry -Line $Lines[$pathStart] -LineNumber ($pathStart + 1)
        $blocks += [PSCustomObject]@{
            Key = $entry.Key
            Line = $entry.Line
            Start = $pathStart
            End = $pathEnd
            Header = $Lines[$pathStart]
            Children = @(Get-BlockChildren -Lines $Lines -Start $pathStart -End $pathEnd)
        }
    }

    return @($blocks)
}

function Join-CompatiblePathBlocks {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Blocks
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $result.Add($Blocks[0].Header)

    $firstChildStart = $Blocks[0].End + 1
    if ($Blocks[0].Children.Count -gt 0) {
        $firstChildStart = $Blocks[0].Children[0].Line - 1
    }
    if ($firstChildStart -gt $Blocks[0].Start + 1) {
        foreach ($line in $script:documentLines[($Blocks[0].Start + 1)..($firstChildStart - 1)]) {
            $result.Add($line)
        }
    }

    $seen = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($block in $Blocks) {
        foreach ($child in $block.Children) {
            $signature = $child.Lines -join "`n"
            if ($seen.ContainsKey($child.Key) -and $seen[$child.Key] -ceq $signature) {
                continue
            }

            if (-not $seen.ContainsKey($child.Key)) {
                $seen.Add($child.Key, $signature)
            }
            foreach ($line in $child.Lines) {
                $result.Add($line)
            }
        }
    }

    return [string[]]$result
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Arquivo OpenAPI não encontrado: $InputPath"
}

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$content = Get-Content -LiteralPath $inputFullPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($content)) {
    throw "O arquivo OpenAPI está vazio: $inputFullPath"
}

$newLine = "`n"
if ($content.Contains("`r`n")) {
    $newLine = "`r`n"
}
$script:documentLines = [string[]]($content -split "`r?`n")

$rootEntries = @()
for ($index = 0; $index -lt $script:documentLines.Count; $index++) {
    $entry = Get-YamlKeyEntry -Line $script:documentLines[$index] -LineNumber ($index + 1)
    if ($null -ne $entry -and $entry.Indent -eq 0) {
        $rootEntries += [PSCustomObject]@{
            Entry = $entry
            Index = $index
        }
    }
}

$pathsRoots = @($rootEntries | Where-Object { $_.Entry.Key -ceq "paths" })
if ($pathsRoots.Count -ne 1) {
    throw "O YAML deve conter exatamente uma seção raiz paths. Encontrado: $($pathsRoots.Count)."
}

$pathsStart = $pathsRoots[0].Index
$pathsEnd = $script:documentLines.Count - 1
$nextRoot = @($rootEntries | Where-Object { $_.Index -gt $pathsStart } | Select-Object -First 1)
if ($nextRoot.Count -eq 1) {
    $pathsEnd = $nextRoot[0].Index - 1
}

$pathBlocks = @(Get-PathBlocks -Lines $script:documentLines -PathsStart $pathsStart -PathsEnd $pathsEnd)
$outputLines = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -le $pathsStart; $index++) {
    $outputLines.Add($script:documentLines[$index])
}

if ($pathBlocks.Count -gt 0 -and $pathBlocks[0].Start -gt $pathsStart + 1) {
    foreach ($line in $script:documentLines[($pathsStart + 1)..($pathBlocks[0].Start - 1)]) {
        $outputLines.Add($line)
    }
}

$processed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($pathBlock in $pathBlocks) {
    if (-not $processed.Add($pathBlock.Key)) {
        continue
    }

    $matches = @($pathBlocks | Where-Object { $_.Key -ceq $pathBlock.Key })
    if ($matches.Count -eq 1) {
        foreach ($line in $script:documentLines[$pathBlock.Start..$pathBlock.End]) {
            $outputLines.Add($line)
        }
        continue
    }

    foreach ($line in (Join-CompatiblePathBlocks -Blocks $matches)) {
        $outputLines.Add($line)
    }
}

if ($pathsEnd + 1 -lt $script:documentLines.Count) {
    foreach ($line in $script:documentLines[($pathsEnd + 1)..($script:documentLines.Count - 1)]) {
        $outputLines.Add($line)
    }
}

$outputContent = $outputLines -join $newLine
$utf8WithoutBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($outputFullPath, $outputContent, $utf8WithoutBom)
