param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
$expectedDescription = "Retorna uma mensagem Hello World gerada por um endpoint TL++."
$expectedResponseDescription = "Hello World retornado com sucesso."

function Get-ExactProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $properties = @($Object.PSObject.Properties | Where-Object { $_.Name -ceq $Name })
    if ($properties.Count -eq 1) {
        return $properties[0]
    }

    return $null
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Arquivo OpenAPI não encontrado: $Path"
}

try {
    $rawDocument = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($rawDocument)) {
        throw "O arquivo está vazio."
    }

    $document = $rawDocument | ConvertFrom-Json
} catch {
    throw "Não foi possível ler um JSON OpenAPI válido em '$Path': $($_.Exception.Message)"
}

if ($null -eq $document -or $document -isnot [PSCustomObject]) {
    throw "A raiz do documento OpenAPI deve ser um objeto JSON."
}

$openApiProperty = Get-ExactProperty -Object $document -Name "openapi"
$swaggerProperty = Get-ExactProperty -Object $document -Name "swagger"
$declaredVersions = @($openApiProperty, $swaggerProperty | Where-Object { $null -ne $_ })

if ($declaredVersions.Count -ne 1) {
    throw "O documento deve declarar exatamente uma versão em openapi ou swagger."
}

if ($null -ne $openApiProperty) {
    if ($openApiProperty.Value -isnot [string] -or $openApiProperty.Value -cnotmatch '^3\.\d+\.\d+$') {
        throw "A versão openapi deve ser uma string no formato 3.x.y."
    }
    $specVersion = $openApiProperty.Value
} else {
    if ($swaggerProperty.Value -isnot [string] -or $swaggerProperty.Value -cne "2.0") {
        throw "A versão swagger deve ser a string 2.0."
    }
    $specVersion = $swaggerProperty.Value
}

$pathsProperty = Get-ExactProperty -Object $document -Name "paths"
if ($null -eq $pathsProperty -or $pathsProperty.Value -isnot [PSCustomObject]) {
    throw "O documento não contém um objeto paths válido."
}

$paths = $pathsProperty.Value
$pathNames = @($paths.PSObject.Properties.Name)
$helloPaths = @($pathNames | Where-Object { $_ -cmatch "/api/v1/hello$" })

if ($helloPaths.Count -ne 1) {
    throw "Esperado exatamente um path terminado em /api/v1/hello; encontrado: $($helloPaths.Count)."
}

$helloPath = $helloPaths[0]
$pathItem = $paths.PSObject.Properties[$helloPath].Value
if ($null -eq $pathItem -or $pathItem -isnot [PSCustomObject]) {
    throw "O path '$helloPath' não contém um objeto de operações válido."
}

$getProperty = Get-ExactProperty -Object $pathItem -Name "get"
if ($null -eq $getProperty -or $null -eq $getProperty.Value) {
    throw "A operação GET não foi encontrada em $helloPath."
}

$operation = $getProperty.Value
$title = [string]$operation.title
$summary = [string]$operation.summary
if ($title -ne "Hello World" -and $summary -ne "Hello World") {
    throw "Título ou summary inesperado. title='$title'; summary='$summary'."
}

if ($operation.description -ne $expectedDescription) {
    throw "Descrição inesperada para a operação Hello World: '$($operation.description)'."
}

if ($null -eq $operation.responses -or $operation.responses -isnot [PSCustomObject]) {
    throw "A operação GET não contém um objeto responses válido."
}

$response200Property = $operation.responses.PSObject.Properties["200"]
if ($null -eq $response200Property -or $null -eq $response200Property.Value) {
    throw "A resposta HTTP 200 não foi documentada."
}

if ($response200Property.Value.description -ne $expectedResponseDescription) {
    throw "Descrição inesperada para a resposta HTTP 200: '$($response200Property.Value.description)'."
}

Write-Output "OpenAPI válido para o experimento. Versão: $specVersion; path: $helloPath."
