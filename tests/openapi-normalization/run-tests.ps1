$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$normalizer = Join-Path $repoRoot "scripts\normalize-openapi-paths.ps1"
$fixtures = Join-Path $PSScriptRoot "fixtures"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("openapi-normalization-" + [guid]::NewGuid().ToString("N"))
$passed = 0
$failed = 0

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-MatchCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [int]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $actual = [regex]::Matches($Content, $Pattern).Count
    if ($actual -ne $Expected) {
        throw "$Message Esperado: $Expected; obtido: $actual."
    }
}

function Invoke-Normalizer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Fixture,

        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    if (-not (Test-Path -LiteralPath $normalizer -PathType Leaf)) {
        throw "Normalizador não encontrado: $normalizer"
    }

    & $normalizer -InputPath (Join-Path $fixtures $Fixture) -OutputPath $Output | Out-Null
}

function Invoke-NormalizerProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFile,

        [Parameter(Mandatory = $true)]
        [string]$Output,

        [switch]$Force
    )

    $powershell = Join-Path $PSHOME "powershell.exe"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $normalizer,
        "-InputPath", $InputFile,
        "-OutputPath", $Output
    )
    if ($Force) {
        $arguments += "-Force"
    }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $message = & $powershell @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Message = $message
    }
}

function Invoke-NormalizerFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Fixture,

        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    return Invoke-NormalizerProcess -InputFile (Join-Path $fixtures $Fixture) -Output $Output
}

function Assert-Utf8WithoutBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    Assert-True -Condition (-not $hasBom) -Message "A saída contém BOM."

    $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
    try {
        $null = $utf8Strict.GetString($bytes)
    } catch {
        throw "A saída não é UTF-8 válida."
    }
}

function Invoke-Test {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    try {
        & $Body
        $script:passed++
        Write-Output "PASS: $Name"
    } catch {
        $script:failed++
        Write-Output "FAIL: $Name - $($_.Exception.Message)"
    }
}

try {
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    Invoke-Test -Name "preserva path único e seções externas" -Body {
        $output = Join-Path $tempRoot "unique.yaml"
        Invoke-Normalizer -Fixture "unique-path.yaml" -Output $output
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8

        Assert-MatchCount -Content $content -Pattern '(?m)^  /api/items:$' -Expected 1 -Message "Path único alterado."
        Assert-MatchCount -Content $content -Pattern '(?m)^    get:$' -Expected 1 -Message "Operação GET ausente."
        Assert-True -Condition $content.Contains("info:") -Message "Seção info ausente."
        Assert-True -Condition $content.Contains("components:") -Message "Seção components ausente."
    }

    Invoke-Test -Name "consolida duas ocorrências com métodos distintos" -Body {
        $output = Join-Path $tempRoot "two.yaml"
        Invoke-Normalizer -Fixture "merge-two-methods.yaml" -Output $output
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8

        Assert-MatchCount -Content $content -Pattern '(?m)^  /api/items/\{id\}:$' -Expected 1 -Message "Path duplicado não consolidado."
        Assert-MatchCount -Content $content -Pattern '(?m)^    get:$' -Expected 1 -Message "Operação GET ausente."
        Assert-MatchCount -Content $content -Pattern '(?m)^    put:$' -Expected 1 -Message "Operação PUT ausente."
    }

    Invoke-Test -Name "consolida três ocorrências preservando a ordem" -Body {
        $output = Join-Path $tempRoot "three.yaml"
        Invoke-Normalizer -Fixture "merge-three-methods.yaml" -Output $output
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8
        $getIndex = $content.IndexOf("    get:", [StringComparison]::Ordinal)
        $postIndex = $content.IndexOf("    post:", [StringComparison]::Ordinal)
        $deleteIndex = $content.IndexOf("    delete:", [StringComparison]::Ordinal)

        Assert-MatchCount -Content $content -Pattern '(?m)^  /api/orders:$' -Expected 1 -Message "Path triplicado não consolidado."
        Assert-True -Condition ($getIndex -ge 0 -and $getIndex -lt $postIndex -and $postIndex -lt $deleteIndex) -Message "Ordem dos métodos não preservada."
    }

    Invoke-Test -Name "mantém uma cópia de campo compartilhado idêntico" -Body {
        $output = Join-Path $tempRoot "shared.yaml"
        Invoke-Normalizer -Fixture "shared-identical.yaml" -Output $output
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8

        Assert-MatchCount -Content $content -Pattern '(?m)^  /api/customers/\{id\}:$' -Expected 1 -Message "Path com campo compartilhado não consolidado."
        Assert-MatchCount -Content $content -Pattern '(?m)^    parameters:$' -Expected 1 -Message "Campo compartilhado não foi deduplicado."
        Assert-MatchCount -Content $content -Pattern '(?m)^    get:$' -Expected 1 -Message "Operação GET ausente."
        Assert-MatchCount -Content $content -Pattern '(?m)^    patch:$' -Expected 1 -Message "Operação PATCH ausente."
    }

    Invoke-Test -Name "rejeita o mesmo verbo repetido" -Body {
        $output = Join-Path $tempRoot "duplicate-method.yaml"
        $result = Invoke-NormalizerFailure -Fixture "duplicate-method.yaml" -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Verbo repetido foi aceito."
        Assert-True -Condition $result.Message.Contains("/api/items/{id}") -Message "Diagnóstico não informa o path."
        Assert-True -Condition $result.Message.Contains("get") -Message "Diagnóstico não informa o verbo."
        Assert-True -Condition ($result.Message.Contains("7") -and $result.Message.Contains("12")) -Message "Diagnóstico não informa as linhas do verbo."
        Assert-True -Condition (-not (Test-Path -LiteralPath $output)) -Message "Falha deixou arquivo de saída."
    }

    Invoke-Test -Name "rejeita campo compartilhado incompatível" -Body {
        $output = Join-Path $tempRoot "shared-conflict.yaml"
        $result = Invoke-NormalizerFailure -Fixture "shared-conflict.yaml" -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Campo compartilhado conflitante foi aceito."
        Assert-True -Condition $result.Message.Contains("/api/customers/{id}") -Message "Diagnóstico não informa o path."
        Assert-True -Condition $result.Message.Contains("parameters") -Message "Diagnóstico não informa o campo."
        Assert-True -Condition ($result.Message.Contains("7") -and $result.Message.Contains("14")) -Message "Diagnóstico não informa as linhas do campo."
        Assert-True -Condition (-not (Test-Path -LiteralPath $output)) -Message "Falha deixou arquivo de saída."
    }

    Invoke-Test -Name "rejeita ausência da seção paths" -Body {
        $output = Join-Path $tempRoot "without-paths.yaml"
        $result = Invoke-NormalizerFailure -Fixture "without-paths.yaml" -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Documento sem paths foi aceito."
        Assert-True -Condition $result.Message.Contains("exatamente uma seção raiz paths") -Message "Diagnóstico inesperado para ausência de paths."
        Assert-True -Condition (-not (Test-Path -LiteralPath $output)) -Message "Falha deixou arquivo de saída."
    }

    Invoke-Test -Name "rejeita duas seções raiz paths" -Body {
        $output = Join-Path $tempRoot "duplicate-root-paths.yaml"
        $result = Invoke-NormalizerFailure -Fixture "duplicate-root-paths.yaml" -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Documento com duas seções paths foi aceito."
        Assert-True -Condition $result.Message.Contains("Encontrado: 2") -Message "Diagnóstico não informa duas seções paths."
        Assert-True -Condition (-not (Test-Path -LiteralPath $output)) -Message "Falha deixou arquivo de saída."
    }

    Invoke-Test -Name "rejeita tabulação na estrutura" -Body {
        $output = Join-Path $tempRoot "tab-indentation.yaml"
        $result = Invoke-NormalizerFailure -Fixture "tab-indentation.yaml" -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Tabulação foi aceita."
        Assert-True -Condition ($result.Message.Contains("tabulação") -and $result.Message.Contains("linha 7")) -Message "Diagnóstico não informa a linha com tabulação."
        Assert-True -Condition (-not (Test-Path -LiteralPath $output)) -Message "Falha deixou arquivo de saída."
    }

    $cedilla = [char]0x00E7
    $tildeA = [char]0x00E3
    $acuteI = [char]0x00ED
    $expectedTitle = "Descri${cedilla}${tildeA}o da a${cedilla}${tildeA}o"
    $expectedDescription = "A${cedilla}${tildeA}o conclu${acuteI}da"
    $encodingSample = @"
openapi: 3.0.3
info:
  title: $expectedTitle
  version: 1.0.0
paths:
  /api/encoding:
    get:
      description: $expectedDescription
"@

    Invoke-Test -Name "aceita UTF-8 com e sem BOM" -Body {
        $utf8NoBomInput = Join-Path $tempRoot "utf8-no-bom-input.yaml"
        $utf8BomInput = Join-Path $tempRoot "utf8-bom-input.yaml"
        $utf8NoBomOutput = Join-Path $tempRoot "utf8-no-bom-output.yaml"
        $utf8BomOutput = Join-Path $tempRoot "utf8-bom-output.yaml"
        [IO.File]::WriteAllText($utf8NoBomInput, $encodingSample, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($utf8BomInput, $encodingSample, [Text.UTF8Encoding]::new($true))

        $first = Invoke-NormalizerProcess -InputFile $utf8NoBomInput -Output $utf8NoBomOutput
        $second = Invoke-NormalizerProcess -InputFile $utf8BomInput -Output $utf8BomOutput

        Assert-True -Condition ($first.ExitCode -eq 0 -and $second.ExitCode -eq 0) -Message "Entrada UTF-8 foi rejeitada."
        Assert-True -Condition (Get-Content -LiteralPath $utf8NoBomOutput -Raw -Encoding UTF8).Contains($expectedTitle) -Message "Acentos do UTF-8 sem BOM foram alterados."
        Assert-True -Condition (Get-Content -LiteralPath $utf8BomOutput -Raw -Encoding UTF8).Contains($expectedDescription) -Message "Acentos do UTF-8 com BOM foram alterados."
    }

    Invoke-Test -Name "aceita CP1252 e publica UTF-8 sem BOM" -Body {
        $input = Join-Path $tempRoot "cp1252-input.yaml"
        $output = Join-Path $tempRoot "cp1252-output.yaml"
        [IO.File]::WriteAllText($input, $encodingSample, [Text.Encoding]::GetEncoding(1252))

        $result = Invoke-NormalizerProcess -InputFile $input -Output $output
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8

        Assert-True -Condition ($result.ExitCode -eq 0) -Message "Entrada CP1252 foi rejeitada."
        Assert-True -Condition $content.Contains($expectedTitle) -Message "Acentos do CP1252 não foram preservados."
        Assert-True -Condition $content.Contains($expectedDescription) -Message "Conteúdo CP1252 foi corrompido."
        Assert-Utf8WithoutBom -Path $output
    }

    Invoke-Test -Name "rejeita entrada e saída iguais" -Body {
        $input = Join-Path $tempRoot "same-path.yaml"
        Copy-Item -LiteralPath (Join-Path $fixtures "unique-path.yaml") -Destination $input
        $before = (Get-FileHash -Algorithm SHA256 -LiteralPath $input).Hash

        $result = Invoke-NormalizerProcess -InputFile $input -Output $input

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Entrada e saída iguais foram aceitas."
        Assert-True -Condition $result.Message.Contains("caminhos de entrada e saída") -Message "Diagnóstico inesperado para caminhos iguais."
        Assert-True -Condition ((Get-FileHash -Algorithm SHA256 -LiteralPath $input).Hash -ceq $before) -Message "Arquivo de entrada foi alterado."
    }

    Invoke-Test -Name "protege destino existente sem Force" -Body {
        $output = Join-Path $tempRoot "existing.yaml"
        [IO.File]::WriteAllText($output, "conteúdo original", [Text.UTF8Encoding]::new($false))

        $result = Invoke-NormalizerProcess -InputFile (Join-Path $fixtures "unique-path.yaml") -Output $output

        Assert-True -Condition ($result.ExitCode -ne 0) -Message "Destino existente foi substituído sem Force."
        Assert-True -Condition $result.Message.Contains("Use -Force") -Message "Diagnóstico inesperado para destino existente."
        Assert-True -Condition ((Get-Content -LiteralPath $output -Raw -Encoding UTF8) -ceq "conteúdo original") -Message "Destino existente foi alterado."
    }

    Invoke-Test -Name "substitui destino atomicamente com Force" -Body {
        $output = Join-Path $tempRoot "forced.yaml"
        [IO.File]::WriteAllText($output, "conteúdo original", [Text.UTF8Encoding]::new($false))

        $result = Invoke-NormalizerProcess -InputFile (Join-Path $fixtures "unique-path.yaml") -Output $output -Force
        $content = Get-Content -LiteralPath $output -Raw -Encoding UTF8

        Assert-True -Condition ($result.ExitCode -eq 0) -Message "Substituição com Force falhou."
        Assert-True -Condition $content.Contains("/api/items:") -Message "Destino não recebeu o YAML normalizado."
        Assert-Utf8WithoutBom -Path $output
    }

    Invoke-Test -Name "emite resumo e remove temporários" -Body {
        $output = Join-Path $tempRoot "summary.yaml"
        $result = Invoke-NormalizerProcess -InputFile (Join-Path $fixtures "merge-three-methods.yaml") -Output $output

        Assert-True -Condition ($result.ExitCode -eq 0) -Message "Normalização para resumo falhou."
        foreach ($label in @("Declarações", "Paths únicos", "Grupos consolidados", "Operações incorporadas")) {
            Assert-True -Condition $result.Message.Contains($label) -Message "Resumo não contém '$label'."
        }
        $temporaryFiles = @(Get-ChildItem -LiteralPath $tempRoot -File | Where-Object { $_.Name -match '^\..*\.(tmp|bak)$' })
        Assert-True -Condition ($temporaryFiles.Count -eq 0) -Message "Arquivos temporários permaneceram após sucesso."
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Output "Testes aprovados: $passed; falhas: $failed."
if ($failed -gt 0) {
    throw "A suíte de normalização apresentou $failed falha(s)."
}
