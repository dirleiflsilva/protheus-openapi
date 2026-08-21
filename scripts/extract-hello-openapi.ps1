param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$validatorPath = Join-Path $PSScriptRoot "validate-hello-openapi.ps1"
$contract = & $validatorPath -Path $InputPath -PassThru

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

$safeInfo = [ordered]@{}
if (-not [string]::IsNullOrWhiteSpace($contract.InfoTitle)) {
    $safeInfo["title"] = $contract.InfoTitle
}
if (-not [string]::IsNullOrWhiteSpace($contract.InfoVersion)) {
    $safeInfo["version"] = $contract.InfoVersion
}

$safeOperation = [ordered]@{}
$safeOperation[$contract.TitleField] = $contract.Title
$safeOperation["description"] = $contract.Description
$safeOperation["responses"] = [ordered]@{
    "200" = [ordered]@{
        "description" = $contract.ResponseDescription
    }
}

$snapshot = [ordered]@{}
$snapshot[$contract.SpecField] = $contract.SpecVersion
$snapshot["info"] = $safeInfo
$snapshot["paths"] = [ordered]@{
    $contract.HelloPath = [ordered]@{
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

Write-Output "Snapshot JSON sanitizado criado em $outputFullPath"
