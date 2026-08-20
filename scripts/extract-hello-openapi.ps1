param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$validatorPath = Join-Path $PSScriptRoot "validate-hello-openapi.ps1"

& $validatorPath -Path $InputPath | Out-Null

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
if ([string]::Equals($inputFullPath, $outputFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Os caminhos de entrada e saída devem ser diferentes."
}

if (Test-Path -LiteralPath $outputFullPath -PathType Container) {
    throw "O caminho de saída aponta para um diretório: $outputFullPath"
}

if ((Test-Path -LiteralPath $outputFullPath -PathType Leaf) -and -not $Force) {
    throw "O arquivo de saída já existe. Use -Force para permitir a substituição: $outputFullPath"
}

$document = Get-Content -LiteralPath $inputFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathNames = @($document.paths.PSObject.Properties.Name)
$helloPaths = @($pathNames | Where-Object { $_ -cmatch "/api/v1/hello$" })
$helloPath = $helloPaths[0]
$pathItem = $document.paths.PSObject.Properties[$helloPath].Value
$getProperty = @($pathItem.PSObject.Properties | Where-Object { $_.Name -ceq "get" })[0]
$operation = $getProperty.Value

$snapshot = [ordered]@{}
if (@($document.PSObject.Properties | Where-Object { $_.Name -ceq "openapi" }).Count -eq 1) {
    $snapshot["openapi"] = @($document.PSObject.Properties | Where-Object { $_.Name -ceq "openapi" })[0].Value
} else {
    $snapshot["swagger"] = @($document.PSObject.Properties | Where-Object { $_.Name -ceq "swagger" })[0].Value
}

$safeInfo = [ordered]@{}
$infoProperty = @($document.PSObject.Properties | Where-Object { $_.Name -ceq "info" })
if ($infoProperty.Count -eq 1 -and $infoProperty[0].Value -is [PSCustomObject]) {
    foreach ($name in @("title", "version")) {
        $property = @($infoProperty[0].Value.PSObject.Properties | Where-Object { $_.Name -ceq $name })
        if ($property.Count -eq 1 -and $property[0].Value -is [string]) {
            $safeInfo[$name] = $property[0].Value
        }
    }
}

$safeOperation = [ordered]@{}
if ([string]$operation.title -ceq "Hello World") {
    $safeOperation["title"] = "Hello World"
} else {
    $safeOperation["summary"] = "Hello World"
}
$safeOperation["description"] = "Retorna uma mensagem Hello World gerada por um endpoint TL++."
$safeOperation["responses"] = [ordered]@{
    "200" = [ordered]@{
        "description" = "Hello World retornado com sucesso."
    }
}

$snapshot["info"] = $safeInfo
$snapshot["paths"] = [ordered]@{
    $helloPath = [ordered]@{
        "get" = $safeOperation
    }
}

$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$temporaryPath = Join-Path $outputDirectory (".{0}.{1}.tmp" -f ([System.IO.Path]::GetFileName($outputFullPath)), [guid]::NewGuid().ToString("N"))
$backupPath = Join-Path $outputDirectory (".{0}.{1}.bak" -f ([System.IO.Path]::GetFileName($outputFullPath)), [guid]::NewGuid().ToString("N"))
try {
    $json = $snapshot | ConvertTo-Json -Depth 10
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8WithoutBom)

    if (Test-Path -LiteralPath $outputFullPath -PathType Leaf) {
        [System.IO.File]::Replace($temporaryPath, $outputFullPath, $backupPath)
    } else {
        [System.IO.File]::Move($temporaryPath, $outputFullPath)
    }
} finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        Remove-Item -LiteralPath $backupPath -Force
    }
}

Write-Output "Snapshot criado em $outputFullPath"
