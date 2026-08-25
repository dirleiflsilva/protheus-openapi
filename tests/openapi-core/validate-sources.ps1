$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$fixturePath = Join-Path $PSScriptRoot "custom.openapi.core.test.tlpp"
$infoPath = Join-Path $repoRoot "src\core\custom.openapi.info.tlpp"
$respPath = Join-Path $repoRoot "src\core\custom.openapi.response.tlpp"
$operPath = Join-Path $repoRoot "src\core\custom.openapi.operation.tlpp"
$pathPath = Join-Path $repoRoot "src\core\custom.openapi.path.tlpp"
$docPath = Join-Path $repoRoot "src\core\custom.openapi.document.tlpp"
$jsonPath = Join-Path $repoRoot "src\core\custom.openapi.json.tlpp"

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

if (-not (Test-Path -LiteralPath $operPath -PathType Leaf)) {
    throw "Fonte OApiOper não encontrado: $operPath"
}

$operContent = Get-Cp1252Content -Path $operPath
$operIncludes = [regex]::Matches(
    $operContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$operExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($operIncludes.Count -lt $operExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiOper."
}

for ($index = 0; $index -lt $operExpectedIncludes.Count; $index++) {
    if ($operIncludes[$index].Groups["name"].Value -cne $operExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiOper: esperado '$($operExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $operContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiOper."
Assert-Match -Content $operContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiOper\b' `
    -Message "Classe OApiOper ausente."

$operDocs = @{}

foreach ($methodName in @("new", "getMethod", "getSummary", "getDesc", "getResps", "addResp", "validate")) {
    $methodMatch = [regex]::Match(
        $operContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiOper::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiOper::$methodName."
    }

    $operDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-25\b'
    )) {
        Assert-Match -Content $operDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiOper::${methodName}: $pattern"
    }
}

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+cMethod,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@param[\t ]+cSummary,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $operDocs["new"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiOper::new: $pattern"
}

foreach ($methodName in @("getMethod", "getSummary", "getDesc")) {
    Assert-Match -Content $operDocs[$methodName] `
        -Pattern '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$' `
        -Message "@return character ausente para OApiOper::$methodName."
}

Assert-Match -Content $operDocs["getResps"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiOper::getResps."

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+oResp,[\t ]+object,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $operDocs["addResp"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiOper::addResp: $pattern"
}

Assert-Match -Content $operDocs["validate"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiOper::validate."

Assert-Match -Content $operContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiOper\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-25\b.*?\*/[\t \r\n]*class[\t ]+OApiOper\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiOper."

$operValidation = [regex]::Replace($operContent, '(?s)/\*.*?\*/', '')
$operValidation = [regex]::Replace($operValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "getMethod", "getSummary", "getDesc", "getResps", "addResp", "validate")) {
    Assert-Match -Content $operValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiOper::$methodName ausente na declaração da classe."
    Assert-Match -Content $operValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiOper\b" `
        -Message "Implementação OApiOper::$methodName ausente."
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

if (-not (Test-Path -LiteralPath $pathPath -PathType Leaf)) {
    throw "Fonte OApiPath não encontrado: $pathPath"
}

$pathContent = Get-Cp1252Content -Path $pathPath
$pathIncludes = [regex]::Matches(
    $pathContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$pathExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($pathIncludes.Count -lt $pathExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiPath."
}

for ($index = 0; $index -lt $pathExpectedIncludes.Count; $index++) {
    if ($pathIncludes[$index].Groups["name"].Value -cne $pathExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiPath: esperado '$($pathExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $pathContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiPath."
Assert-Match -Content $pathContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiPath\b' `
    -Message "Classe OApiPath ausente."

$pathDocs = @{}

foreach ($methodName in @("new", "getPath", "getOpers", "addOper", "validate")) {
    $methodMatch = [regex]::Match(
        $pathContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiPath::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiPath::$methodName."
    }

    $pathDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-25\b'
    )) {
        Assert-Match -Content $pathDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiPath::${methodName}: $pattern"
    }
}

if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
    throw "Fonte OApiDoc não encontrado: $docPath"
}

$docContent = Get-Cp1252Content -Path $docPath
$docIncludes = [regex]::Matches(
    $docContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$docExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($docIncludes.Count -lt $docExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiDoc."
}

for ($index = 0; $index -lt $docExpectedIncludes.Count; $index++) {
    if ($docIncludes[$index].Groups["name"].Value -cne $docExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiDoc: esperado '$($docExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $docContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiDoc."
Assert-Match -Content $docContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiDoc\b' `
    -Message "Classe OApiDoc ausente."

$docDocs = @{}

foreach ($methodName in @("new", "getOpenApi", "getInfo", "getPaths", "addPath", "validate")) {
    $methodMatch = [regex]::Match(
        $docContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiDoc::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiDoc::$methodName."
    }

    $docDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-25\b'
    )) {
        Assert-Match -Content $docDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiDoc::${methodName}: $pattern"
    }
}

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+oInfo,[\t ]+object,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $docDocs["new"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiDoc::new: $pattern"
}

Assert-Match -Content $docDocs["getOpenApi"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$' `
    -Message "@return character ausente para OApiDoc::getOpenApi."

Assert-Match -Content $docDocs["getInfo"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$' `
    -Message "@return object ausente para OApiDoc::getInfo."

Assert-Match -Content $docDocs["getPaths"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiDoc::getPaths."

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+oPath,[\t ]+object,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $docDocs["addPath"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiDoc::addPath: $pattern"
}

Assert-Match -Content $docDocs["validate"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiDoc::validate."

Assert-Match -Content $docContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiDoc\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-25\b.*?\*/[\t \r\n]*class[\t ]+OApiDoc\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiDoc."

$docValidation = [regex]::Replace($docContent, '(?s)/\*.*?\*/', '')
$docValidation = [regex]::Replace($docValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "getOpenApi", "getInfo", "getPaths", "addPath", "validate")) {
    Assert-Match -Content $docValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiDoc::$methodName ausente na declaração da classe."
    Assert-Match -Content $docValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiDoc\b" `
        -Message "Implementação OApiDoc::$methodName ausente."
}

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+cPath,[\t ]+character,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $pathDocs["new"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiPath::new: $pattern"
}

Assert-Match -Content $pathDocs["getPath"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$' `
    -Message "@return character ausente para OApiPath::getPath."

Assert-Match -Content $pathDocs["getOpers"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiPath::getOpers."

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+oOper,[\t ]+object,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $pathDocs["addOper"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiPath::addOper: $pattern"
}

Assert-Match -Content $pathDocs["validate"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+$' `
    -Message "@return array ausente para OApiPath::validate."

Assert-Match -Content $pathContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiPath\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-25\b.*?\*/[\t \r\n]*class[\t ]+OApiPath\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiPath."

$pathValidation = [regex]::Replace($pathContent, '(?s)/\*.*?\*/', '')
$pathValidation = [regex]::Replace($pathValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "getPath", "getOpers", "addOper", "validate")) {
    Assert-Match -Content $pathValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiPath::$methodName ausente na declaração da classe."
    Assert-Match -Content $pathValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiPath\b" `
        -Message "Implementação OApiPath::$methodName ausente."
}

if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) {
    throw "Fonte OApiJson não encontrado: $jsonPath"
}

$jsonContent = Get-Cp1252Content -Path $jsonPath
$jsonIncludes = [regex]::Matches(
    $jsonContent,
    '(?im)^[\t ]*#include[\t ]+["''](?<name>[^"'']+)["''][\t ]*\r?$'
)
$jsonExpectedIncludes = @("tlpp-core.th", "totvs.ch")

if ($jsonIncludes.Count -lt $jsonExpectedIncludes.Count) {
    throw "Includes obrigatórios ausentes no fonte OApiJson."
}

for ($index = 0; $index -lt $jsonExpectedIncludes.Count; $index++) {
    if ($jsonIncludes[$index].Groups["name"].Value -cne $jsonExpectedIncludes[$index]) {
        throw "Ordem de includes inválida no OApiJson: esperado '$($jsonExpectedIncludes[$index])' na posição $($index + 1)."
    }
}

Assert-Match -Content $jsonContent `
    -Pattern '(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core[\t ]*\r?$' `
    -Message "Namespace custom.openapi.core ausente no OApiJson."
Assert-Match -Content $jsonContent `
    -Pattern '(?im)^[\t ]*class[\t ]+OApiJson\b' `
    -Message "Classe OApiJson ausente."

$jsonDocs = @{}

foreach ($methodName in @("new", "toJson")) {
    $methodMatch = [regex]::Match(
        $jsonContent,
        "(?is)(?<doc>/\*/\{Protheus\.doc\}[\t ]+OApiJson::$methodName\b.*?\*/)[\t \r\n]*method[\t ]+$methodName[\t ]*\("
    )

    if (-not $methodMatch.Success) {
        throw "ProtheusDOC obrigatório ausente para OApiJson::$methodName."
    }

    $jsonDocs[$methodName] = $methodMatch.Groups["doc"].Value

    foreach ($pattern in @(
        '(?im)^[\t ]*@type[\t ]+method\b',
        '(?im)^[\t ]*@author[\t ]+Dirlei Silva\b',
        '(?im)^[\t ]*@since[\t ]+2026-08-25\b'
    )) {
        Assert-Match -Content $jsonDocs[$methodName] `
            -Pattern $pattern `
            -Message "ProtheusDOC incompleto para OApiJson::${methodName}: $pattern"
    }
}

Assert-Match -Content $jsonDocs["new"] `
    -Pattern '(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+$' `
    -Message "@return object ausente para OApiJson::new."

foreach ($pattern in @(
    '(?im)^[\t ]*@param[\t ]+oDoc,[\t ]+object,[\t ]+[^\r\n]+$',
    '(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+$'
)) {
    Assert-Match -Content $jsonDocs["toJson"] `
        -Pattern $pattern `
        -Message "ProtheusDOC incompleto para OApiJson::toJson: $pattern"
}

Assert-Match -Content $jsonContent `
    -Pattern '(?is)/\*/\{Protheus\.doc\}[\t ]+OApiJson\b.*?@type[\t ]+class\b.*?@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-08-25\b.*?\*/[\t \r\n]*class[\t ]+OApiJson\b' `
    -Message "ProtheusDOC obrigatório ausente para a classe OApiJson."

$jsonValidation = [regex]::Replace($jsonContent, '(?s)/\*.*?\*/', '')
$jsonValidation = [regex]::Replace($jsonValidation, '(?m)//[^\r\n]*', '')

foreach ($methodName in @("new", "toJson")) {
    Assert-Match -Content $jsonValidation `
        -Pattern "(?im)^[\t ]*public[\t ]+method[\t ]+$methodName[\t ]*\(" `
        -Message "Método público OApiJson::$methodName ausente na declaração da classe."
    Assert-Match -Content $jsonValidation `
        -Pattern "(?im)^[\t ]*method[\t ]+$methodName[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiJson\b" `
        -Message "Implementação OApiJson::$methodName ausente."
}

$toJsonMatch = [regex]::Match(
    $jsonValidation,
    '(?is)method[\t ]+toJson[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiJson\b(?<body>.*?)(?=^[\t ]*method\b|\z)'
)

if (-not $toJsonMatch.Success) {
    throw "Corpo de OApiJson::toJson não encontrado."
}

$toJsonBody = $toJsonMatch.Groups["body"].Value
$validateMatch = [regex]::Match($toJsonBody, '(?i)oDoc[\t ]*:[\t ]*validate[\t ]*\(')
$newMatch = [regex]::Match($toJsonBody, '(?i)JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(')
$serializeMatch = [regex]::Match($toJsonBody, '(?i):[\t ]*ToJson[\t ]*\(')

if (-not $validateMatch.Success) {
    throw "OApiJson::toJson deve validar o documento antes de serializar."
}

if (-not $newMatch.Success) {
    throw "JsonObject():New() ausente em OApiJson::toJson."
}

if ($validateMatch.Index -gt $newMatch.Index) {
    throw "OApiJson::toJson deve validar antes de criar a saída JSON."
}

if (-not $serializeMatch.Success -or $serializeMatch.Index -lt $newMatch.Index) {
    throw "ToJson() ausente após a criação do objeto JSON."
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
