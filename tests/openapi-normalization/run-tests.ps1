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

function Invoke-NormalizerFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Fixture,

        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    $powershell = Join-Path $PSHOME "powershell.exe"
    $input = Join-Path $fixtures $Fixture
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $message = & $powershell -NoProfile -ExecutionPolicy Bypass -File $normalizer -InputPath $input -OutputPath $Output 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Message = $message
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
} finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Output "Testes aprovados: $passed; falhas: $failed."
if ($failed -gt 0) {
    throw "A suíte de normalização apresentou $failed falha(s)."
}
