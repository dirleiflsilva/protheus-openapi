param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
$expectedTitle = "Hello World"
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

function ConvertFrom-YamlScalar {
    param(
        [AllowEmptyString()]
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

function Get-YamlEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $entries = @()
    $lines = $Content -split "`r?`n"

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith("#") -or $line.Trim() -eq "---") {
            continue
        }

        if ($line.Contains("`t")) {
            throw "O YAML contém tabulação na linha $($lineIndex + 1); use somente espaços para indentação."
        }

        $match = [regex]::Match($line, '^(?<spaces> *)(?<key>''[^'']*''|"[^"]*"|[^:#][^:]*?):[ ]*(?<value>.*)$')
        if (-not $match.Success) {
            # Listas escalares e blocos multilinha não fazem parte do contrato
            # mínimo validado neste experimento.
            continue
        }

        $entries += [PSCustomObject]@{
            Order = $entries.Count
            Line = $lineIndex + 1
            Indent = $match.Groups["spaces"].Value.Length
            Key = ConvertFrom-YamlScalar -Value $match.Groups["key"].Value
            Value = ConvertFrom-YamlScalar -Value $match.Groups["value"].Value
        }
    }

    return @($entries)
}

function Get-YamlRootEntries {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Entries
    )

    return @($Entries | Where-Object { $_.Indent -eq 0 })
}

function Get-YamlDirectChildren {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Entries,

        [Parameter(Mandatory = $true)]
        [object]$Parent
    )

    $descendants = @()
    for ($index = $Parent.Order + 1; $index -lt $Entries.Count; $index++) {
        $entry = $Entries[$index]
        if ($entry.Indent -le $Parent.Indent) {
            break
        }
        $descendants += $entry
    }

    if ($descendants.Count -eq 0) {
        return @()
    }

    $directIndent = ($descendants | Measure-Object -Property Indent -Minimum).Minimum
    return @($descendants | Where-Object { $_.Indent -eq $directIndent })
}

function Get-ExactYamlChild {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Entries,

        [Parameter(Mandatory = $true)]
        [object]$Parent,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $matches = @(Get-YamlDirectChildren -Entries $Entries -Parent $Parent | Where-Object { $_.Key -ceq $Name })
    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    return $null
}

function Test-SpecVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Field,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if ($Field -ceq "openapi" -and $Version -cnotmatch '^3\.[0-9]+\.[0-9]+$') {
        throw "A versão openapi deve ser uma string no formato 3.x.y."
    }

    if ($Field -ceq "swagger" -and $Version -cne "2.0") {
        throw "A versão swagger deve ser a string 2.0."
    }
}

function Read-JsonContract {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    try {
        $document = $Content | ConvertFrom-Json
    } catch {
        throw "Não foi possível interpretar o JSON OpenAPI: $($_.Exception.Message)"
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
        if ($openApiProperty.Value -isnot [string]) {
            throw "A versão openapi deve ser uma string no formato 3.x.y."
        }
        $specField = "openapi"
        $specVersion = $openApiProperty.Value
    } else {
        if ($swaggerProperty.Value -isnot [string]) {
            throw "A versão swagger deve ser a string 2.0."
        }
        $specField = "swagger"
        $specVersion = $swaggerProperty.Value
    }
    Test-SpecVersion -Field $specField -Version $specVersion

    $pathsProperty = Get-ExactProperty -Object $document -Name "paths"
    if ($null -eq $pathsProperty -or $pathsProperty.Value -isnot [PSCustomObject]) {
        throw "O documento não contém um objeto paths válido."
    }

    $helloPaths = @($pathsProperty.Value.PSObject.Properties.Name | Where-Object { $_ -cmatch '/api/v1/hello$' })
    if ($helloPaths.Count -ne 1) {
        throw "Esperado exatamente um path terminado em /api/v1/hello; encontrado: $($helloPaths.Count)."
    }

    $helloPath = $helloPaths[0]
    $pathItem = $pathsProperty.Value.PSObject.Properties[$helloPath].Value
    $getProperty = Get-ExactProperty -Object $pathItem -Name "get"
    if ($null -eq $getProperty -or $getProperty.Value -isnot [PSCustomObject]) {
        throw "A operação GET não foi encontrada em $helloPath."
    }

    $operation = $getProperty.Value
    $titleProperty = Get-ExactProperty -Object $operation -Name "title"
    $summaryProperty = Get-ExactProperty -Object $operation -Name "summary"
    $titleProperties = @($titleProperty, $summaryProperty | Where-Object { $null -ne $_ })
    if ($titleProperties.Count -ne 1 -or $titleProperties[0].Value -cne $expectedTitle) {
        throw "A operação deve declarar exatamente title ou summary com o valor Hello World."
    }

    $descriptionProperty = Get-ExactProperty -Object $operation -Name "description"
    if ($null -eq $descriptionProperty -or $descriptionProperty.Value -cne $expectedDescription) {
        throw "Descrição inesperada para a operação Hello World."
    }

    $responsesProperty = Get-ExactProperty -Object $operation -Name "responses"
    if ($null -eq $responsesProperty -or $responsesProperty.Value -isnot [PSCustomObject]) {
        throw "A operação GET não contém um objeto responses válido."
    }

    $response200Property = Get-ExactProperty -Object $responsesProperty.Value -Name "200"
    if ($null -eq $response200Property -or $response200Property.Value -isnot [PSCustomObject]) {
        throw "A resposta HTTP 200 não foi documentada."
    }

    $responseDescriptionProperty = Get-ExactProperty -Object $response200Property.Value -Name "description"
    if ($null -eq $responseDescriptionProperty -or $responseDescriptionProperty.Value -cne $expectedResponseDescription) {
        throw "Descrição inesperada para a resposta HTTP 200."
    }

    $infoTitle = ""
    $infoVersion = ""
    $infoProperty = Get-ExactProperty -Object $document -Name "info"
    if ($null -ne $infoProperty -and $infoProperty.Value -is [PSCustomObject]) {
        $property = Get-ExactProperty -Object $infoProperty.Value -Name "title"
        if ($null -ne $property -and $property.Value -is [string]) {
            $infoTitle = $property.Value
        }
        $property = Get-ExactProperty -Object $infoProperty.Value -Name "version"
        if ($null -ne $property -and $property.Value -is [string]) {
            $infoVersion = $property.Value
        }
    }

    return [PSCustomObject]@{
        SpecField = $specField
        SpecVersion = $specVersion
        InfoTitle = $infoTitle
        InfoVersion = $infoVersion
        HelloPath = $helloPath
        TitleField = $titleProperties[0].Name
        Title = $expectedTitle
        Description = $expectedDescription
        ResponseDescription = $expectedResponseDescription
    }
}

function Read-YamlContract {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $entries = @(Get-YamlEntries -Content $Content)
    $roots = @(Get-YamlRootEntries -Entries $entries)
    $versionEntries = @($roots | Where-Object { $_.Key -ceq "openapi" -or $_.Key -ceq "swagger" })
    if ($versionEntries.Count -ne 1) {
        throw "O YAML deve declarar exatamente uma versão em openapi ou swagger."
    }

    $specField = $versionEntries[0].Key
    $specVersion = $versionEntries[0].Value
    Test-SpecVersion -Field $specField -Version $specVersion

    $pathsEntries = @($roots | Where-Object { $_.Key -ceq "paths" })
    if ($pathsEntries.Count -ne 1) {
        throw "O YAML não contém uma seção paths válida."
    }

    $pathEntries = @(Get-YamlDirectChildren -Entries $entries -Parent $pathsEntries[0])
    $duplicatePaths = @($pathEntries | Group-Object -Property Key -CaseSensitive | Where-Object { $_.Count -gt 1 })
    if ($duplicatePaths.Count -gt 0) {
        $duplicateDetails = @($duplicatePaths | ForEach-Object {
            $lineNumbers = @($_.Group | ForEach-Object { $_.Line }) -join ", "
            "$($_.Name) (linhas $lineNumbers)"
        })
        throw "O YAML contém chaves de path duplicadas: $($duplicateDetails -join '; ')."
    }

    $helloEntries = @($pathEntries | Where-Object { $_.Key -cmatch '/api/v1/hello$' })
    if ($helloEntries.Count -ne 1) {
        throw "Esperado exatamente um path terminado em /api/v1/hello; encontrado: $($helloEntries.Count)."
    }

    $helloEntry = $helloEntries[0]
    $getEntry = Get-ExactYamlChild -Entries $entries -Parent $helloEntry -Name "get"
    if ($null -eq $getEntry) {
        throw "A operação GET não foi encontrada em $($helloEntry.Key)."
    }

    $titleEntry = Get-ExactYamlChild -Entries $entries -Parent $getEntry -Name "title"
    $summaryEntry = Get-ExactYamlChild -Entries $entries -Parent $getEntry -Name "summary"
    $titleEntries = @($titleEntry, $summaryEntry | Where-Object { $null -ne $_ })
    if ($titleEntries.Count -ne 1 -or $titleEntries[0].Value -cne $expectedTitle) {
        throw "A operação deve declarar exatamente title ou summary com o valor Hello World."
    }

    $descriptionEntry = Get-ExactYamlChild -Entries $entries -Parent $getEntry -Name "description"
    if ($null -eq $descriptionEntry -or $descriptionEntry.Value -cne $expectedDescription) {
        throw "Descrição inesperada para a operação Hello World."
    }

    $responsesEntry = Get-ExactYamlChild -Entries $entries -Parent $getEntry -Name "responses"
    if ($null -eq $responsesEntry) {
        throw "A operação GET não contém uma seção responses válida."
    }

    $response200Entry = Get-ExactYamlChild -Entries $entries -Parent $responsesEntry -Name "200"
    if ($null -eq $response200Entry) {
        throw "A resposta HTTP 200 não foi documentada."
    }

    $responseDescriptionEntry = Get-ExactYamlChild -Entries $entries -Parent $response200Entry -Name "description"
    if ($null -eq $responseDescriptionEntry -or $responseDescriptionEntry.Value -cne $expectedResponseDescription) {
        throw "Descrição inesperada para a resposta HTTP 200."
    }

    $infoTitle = ""
    $infoVersion = ""
    $infoEntries = @($roots | Where-Object { $_.Key -ceq "info" })
    if ($infoEntries.Count -eq 1) {
        $entry = Get-ExactYamlChild -Entries $entries -Parent $infoEntries[0] -Name "title"
        if ($null -ne $entry) {
            $infoTitle = $entry.Value
        }
        $entry = Get-ExactYamlChild -Entries $entries -Parent $infoEntries[0] -Name "version"
        if ($null -ne $entry) {
            $infoVersion = $entry.Value
        }
    }

    return [PSCustomObject]@{
        SpecField = $specField
        SpecVersion = $specVersion
        InfoTitle = $infoTitle
        InfoVersion = $infoVersion
        HelloPath = $helloEntry.Key
        TitleField = $titleEntries[0].Key
        Title = $expectedTitle
        Description = $expectedDescription
        ResponseDescription = $expectedResponseDescription
    }
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Arquivo OpenAPI não encontrado: $Path"
}

try {
    $rawDocument = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
} catch {
    throw "Não foi possível ler o documento OpenAPI em '$Path': $($_.Exception.Message)"
}

if ([string]::IsNullOrWhiteSpace($rawDocument)) {
    throw "O arquivo OpenAPI está vazio: $Path"
}

$extension = [IO.Path]::GetExtension($Path)
if ($extension -ceq ".yaml" -or $extension -ceq ".yml") {
    $contract = Read-YamlContract -Content $rawDocument
} elseif ($extension -ceq ".json") {
    $contract = Read-JsonContract -Content $rawDocument
} else {
    throw "Extensão OpenAPI não suportada: $extension. Use .yaml, .yml ou .json."
}

if ($PassThru) {
    return $contract
}

Write-Output "OpenAPI válido para o experimento. Versão: $($contract.SpecVersion); path: $($contract.HelloPath)."
