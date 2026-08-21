param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Read-OpenApiText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) {
        $offset = 3
    }

    $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
    try {
        return $utf8Strict.GetString($bytes, $offset, $bytes.Length - $offset)
    } catch [Text.DecoderFallbackException] {
        return [Text.Encoding]::GetEncoding(1252).GetString($bytes)
    }
}

function Test-HttpMethod {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $Name -cin @("get", "put", "post", "delete", "options", "head", "patch", "trace")
}

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

    $seen = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $operationsAdded = 0
    for ($blockIndex = 0; $blockIndex -lt $Blocks.Count; $blockIndex++) {
        $block = $Blocks[$blockIndex]
        foreach ($child in $block.Children) {
            $signature = $child.Lines -join "`n"
            if ($seen.ContainsKey($child.Key)) {
                $previous = $seen[$child.Key]
                if (Test-HttpMethod -Name $child.Key) {
                    throw "O path '$($Blocks[0].Key)' repete o verbo '$($child.Key)' nas linhas $($previous.Line) e $($child.Line)."
                }
                if ($previous.Signature -ceq $signature) {
                    continue
                }
                throw "O path '$($Blocks[0].Key)' contém o campo compartilhado '$($child.Key)' incompatível nas linhas $($previous.Line) e $($child.Line)."
            }

            $seen.Add($child.Key, [PSCustomObject]@{
                Line = $child.Line
                Signature = $signature
            })
            if ($blockIndex -gt 0 -and (Test-HttpMethod -Name $child.Key)) {
                $operationsAdded++
            }
            foreach ($line in $child.Lines) {
                $result.Add($line)
            }
        }
    }

    return [PSCustomObject]@{
        Lines = [string[]]$result
        OperationsAdded = $operationsAdded
    }
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Arquivo OpenAPI não encontrado: $InputPath"
}

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if ([string]::Equals($inputFullPath, $outputFullPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Os caminhos de entrada e saída devem ser diferentes."
}
if ((Test-Path -LiteralPath $outputFullPath -PathType Leaf) -and -not $Force) {
    throw "O arquivo de saída já existe. Use -Force para permitir a substituição: $outputFullPath"
}

$content = Read-OpenApiText -Path $inputFullPath
if ([string]::IsNullOrWhiteSpace($content)) {
    throw "O arquivo OpenAPI está vazio: $inputFullPath"
}

$newLine = "`n"
if ($content.Contains("`r`n")) {
    $newLine = "`r`n"
}
$script:documentLines = [string[]]($content -split "`r?`n")

for ($index = 0; $index -lt $script:documentLines.Count; $index++) {
    if ($script:documentLines[$index].Contains("`t")) {
        throw "O YAML contém tabulação na linha $($index + 1); use somente espaços para indentação."
    }
}

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
$groupsMerged = 0
$operationsAdded = 0
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

    $groupsMerged++
    $merged = Join-CompatiblePathBlocks -Blocks $matches
    $operationsAdded += $merged.OperationsAdded
    foreach ($line in $merged.Lines) {
        $outputLines.Add($line)
    }
}

if ($pathsEnd + 1 -lt $script:documentLines.Count) {
    foreach ($line in $script:documentLines[($pathsEnd + 1)..($script:documentLines.Count - 1)]) {
        $outputLines.Add($line)
    }
}

$outputContent = $outputLines -join $newLine
$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$temporaryPath = Join-Path $outputDirectory (".{0}.{1}.tmp" -f ([IO.Path]::GetFileName($outputFullPath)), [guid]::NewGuid().ToString("N"))
$backupPath = Join-Path $outputDirectory (".{0}.{1}.bak" -f ([IO.Path]::GetFileName($outputFullPath)), [guid]::NewGuid().ToString("N"))
$utf8WithoutBom = [Text.UTF8Encoding]::new($false)
try {
    [IO.File]::WriteAllText($temporaryPath, $outputContent, $utf8WithoutBom)
    if (Test-Path -LiteralPath $outputFullPath -PathType Leaf) {
        [IO.File]::Replace($temporaryPath, $outputFullPath, $backupPath)
    } else {
        [IO.File]::Move($temporaryPath, $outputFullPath)
    }
} finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        Remove-Item -LiteralPath $backupPath -Force
    }
}

Write-Output ("Normalização concluída. Declarações: {0}; Paths únicos: {1}; Grupos consolidados: {2}; Operações incorporadas: {3}." -f $pathBlocks.Count, $processed.Count, $groupsMerged, $operationsAdded)
