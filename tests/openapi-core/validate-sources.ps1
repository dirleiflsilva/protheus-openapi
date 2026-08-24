$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$fixturePath = Join-Path $PSScriptRoot "custom.openapi.core.test.tlpp"

function Get-Cp1252Content {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Fonte de teste não encontrado: $Path"
    }

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) -or
        ($bytes.Length -ge 2 -and
        (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or
        ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)))

    if ($hasBom) {
        throw "O fonte possui BOM não permitido: $Path"
    }

    $hasNonAscii = $bytes | Where-Object { $_ -gt 0x7F } | Select-Object -First 1
    if ($null -ne $hasNonAscii) {
        $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
        try {
            $null = $utf8Strict.GetString($bytes)
            throw "O fonte está em UTF-8 sem BOM: $Path"
        } catch [Text.DecoderFallbackException] {
            # A falha de decodificação UTF-8 é esperada para o fonte CP1252.
        }
    }

    return [Text.Encoding]::GetEncoding(1252).GetString($bytes)
}

function Assert-Match {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$content = Get-Cp1252Content -Path $fixturePath
$includeMatches = [regex]::Matches(
    $content,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$expectedIncludes = @("tlpp-core.th", "tlpp-probat.th", "totvs.ch")

if ($includeMatches.Count -lt $expectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fixture PROBAT."
}

for ($index = 0; $index -lt $expectedIncludes.Count; $index++) {
    if ($includeMatches[$index].Groups["name"].Value -cne $expectedIncludes[$index]) {
        throw "Ordem de includes inválida: esperado '$($expectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $content `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core\.test[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core.test ausente."
Assert-Match -Content $content `
    -Pattern '(?m)^[\t ]*using[\t ]+namespace[\t ]+tlpp\.probat[\t ]*\r?$' `
    -Message "Importação do namespace tlpp.probat ausente."

$fixtureDeclaration = [regex]::Match(
    $content,
    '(?ms)(?<doc>/\*/\{Protheus\.doc\}.*?\*/)[\t \r\n]*@TestFixture[\t ]*\([\t ]*\)[\t \r\n]*User[\t ]+Function[\t ]+OApiTst[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$'
)

if (-not $fixtureDeclaration.Success) {
    throw "Sequência ProtheusDOC, @TestFixture() e User Function OApiTst() ausente."
}

foreach ($pattern in @(
    '(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$',
    '(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$',
    '(?m)^[\t ]*@since[\t ]+2026-08-24[\t ]*\r?$',
    '(?m)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$'
)) {
    Assert-Match -Content $fixtureDeclaration.Groups["doc"].Value `
        -Pattern $pattern `
        -Message "ProtheusDOC obrigatório ausente no fixture: $pattern"
}

$validationContent = [regex]::Replace($content, '(?s)/\*.*?\*/', '')
$validationContent = [regex]::Replace($validationContent, '(?m)//[^\r\n]*', '')

Assert-Match -Content $validationContent `
    -Pattern '(?im)^[\t ]*assertEquals[\t ]*\([\t ]*\.T\.[\t ]*,[\t ]*\.T\.' `
    -Message "Asserção smoke GREEN do PROBAT ausente."

$forbidden = @{
    '(?im)^[\t ]*Function[\t ]+' = "Function não pode ser usado em customizações."
    '(?im)^[\t ]*User[\t ]+Function[\t ]+U_' = "Não declare o prefixo U_ explicitamente."
    '(?i)\btlpp\.doc\.generate[\t ]*\(' = "O núcleo não pode depender de tlpp.doc.generate()."
    '(?i)\b(FOpen|FCreate|FRead|FWrite|MemoRead|MemoWrite|Directory)[\t ]*\(' = "O núcleo não pode depender de filesystem."
}

$sourceRoots = @(
    (Join-Path $repoRoot "src\core"),
    (Join-Path $repoRoot "tests\openapi-core"),
    (Join-Path $repoRoot "examples\openapi-core")
)

foreach ($sourceRoot in $sourceRoots) {
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        continue
    }

    foreach ($source in Get-ChildItem -LiteralPath $sourceRoot -Filter "*.tlpp" -File) {
        $sourceContent = Get-Cp1252Content -Path $source.FullName
        $sourceValidation = [regex]::Replace($sourceContent, '(?s)/\*.*?\*/', '')
        $sourceValidation = [regex]::Replace($sourceValidation, '(?m)//[^\r\n]*', '')

        foreach ($entry in $forbidden.GetEnumerator()) {
            if ($sourceValidation -match $entry.Key) {
                throw "$($entry.Value) Fonte: $($source.FullName)"
            }
        }
    }
}

Write-Output "Contrato do núcleo OpenAPI válido."
