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
} finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Output "Testes aprovados: $passed; falhas: $failed."
if ($failed -gt 0) {
    throw "A suíte de normalização apresentou $failed falha(s)."
}
