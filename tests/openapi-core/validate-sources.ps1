$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$fixturePath = Join-Path $PSScriptRoot "custom.openapi.core.test.tlpp"
$infoPath = Join-Path $repoRoot "src\core\custom.openapi.info.tlpp"
$respPath = Join-Path $repoRoot "src\core\custom.openapi.response.tlpp"

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

if (-not (Test-Path -LiteralPath $infoPath -PathType Leaf)) {
    throw "Fonte OApiInfo não encontrado: $infoPath"
}

$infoContent = Get-Cp1252Content -Path $infoPath
$infoIncludes = [regex]::Matches(
    $infoContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$infoExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($infoIncludes.Count -lt $infoExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiInfo."
}

for ($index = 0; $index -lt $infoExpectedIncludes.Count; $index++) {
    if ($infoIncludes[$index].Groups["name"].Value -cne $infoExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiInfo: esperado '$($infoExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $infoContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiInfo."
Assert-Match -Content $infoContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiInfo\b' `
    -Message "Classe OApiInfo ausente."

$methodDocs = @{}

foreach ($methodName in @("new", "getTitle", "getDesc", "getVer", "validate")) {
    $methodMatch = [regex]::Match(
        $infoContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiInfo::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiInfo::$methodName."
    }

    $methodDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-24\b'
    )) {
        Assert-Match -Content $methodDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiInfo::${methodName}: $pattern"
    }
}

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+cTitle,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@param[\t ]+cApiVer,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $methodDocs["new"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiInfo::new: $pattern"
}

foreach ($methodName in @("getTitle", "getDesc", "getVer")) {
    Assert-Match -Content $methodDocs[$methodName] `
        -Pattern '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$' `
        -Message "@return character ausente para OApiInfo::$methodName."
}

Assert-Match -Content $methodDocs["validate"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiInfo::validate."

Assert-Match -Content $infoContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiInfo\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-24\b.*?\*/[\t \r\n]*class[\t ]+OApiInfo\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiInfo."

$infoValidation = [regex]::Replace($infoContent, '(?s)/\*.*?\*/', '')
$infoValidation = [regex]::Replace($infoValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "getTitle", "getDesc", "getVer", "validate")) {
    Assert-Match -Content $infoValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiInfo::$methodName ausente na declaração da classe."
    Assert-Match -Content $infoValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiInfo\b" `
        -Message "Implementação OApiInfo::$methodName ausente."
}

if (-not (Test-Path -LiteralPath $respPath -PathType Leaf)) {
    throw "Fonte OApiResp não encontrado: $respPath"
}

$respContent = Get-Cp1252Content -Path $respPath
$respIncludes = [regex]::Matches(
    $respContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$respExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($respIncludes.Count -lt $respExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiResp."
}

for ($index = 0; $index -lt $respExpectedIncludes.Count; $index++) {
    if ($respIncludes[$index].Groups["name"].Value -cne $respExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiResp: esperado '$($respExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $respContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiResp."
Assert-Match -Content $respContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiResp\b' `
    -Message "Classe OApiResp ausente."

$respDocs = @{}

foreach ($methodName in @("new", "getCode", "getDesc", "validate")) {
    $methodMatch = [regex]::Match(
        $respContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiResp::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiResp::$methodName."
    }

    $respDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-24\b'
    )) {
        Assert-Match -Content $respDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiResp::${methodName}: $pattern"
    }
}

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+cCode,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $respDocs["new"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiResp::new: $pattern"
}

foreach ($methodName in @("getCode", "getDesc")) {
    Assert-Match -Content $respDocs[$methodName] `
        -Pattern '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$' `
        -Message "@return character ausente para OApiResp::$methodName."
}

Assert-Match -Content $respDocs["validate"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiResp::validate."

Assert-Match -Content $respContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiResp\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-24\b.*?\*/[\t \r\n]*class[\t ]+OApiResp\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiResp."

$respValidation = [regex]::Replace($respContent, '(?s)/\*.*?\*/', '')
$respValidation = [regex]::Replace($respValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "getCode", "getDesc", "validate")) {
    Assert-Match -Content $respValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiResp::$methodName ausente na declaração da classe."
    Assert-Match -Content $respValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiResp\b" `
        -Message "Implementação OApiResp::$methodName ausente."
}

$forbidden = @{
    '(?im)^[\t ]*Function[\t ]+' = "Function não pode ser usado em customizações."
    '(?im)^[\t ]*User[\t ]+Function[\t ]+U_' = "Não declare o prefixo U_ explicitamente."
    '(?i)\bcVer\b' = "Identificador cVer proibido: conflito com macro cVer de sigawin.ch."
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
