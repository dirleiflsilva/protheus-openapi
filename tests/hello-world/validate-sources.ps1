param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("hello", "export", "advpl")]
    [string]$Target
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

$contracts = @{
    hello = @{
        Path = Join-Path $repoRoot "examples\hello-world\hello-api.tlpp"
        DocumentationPatterns = @(
            '(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$',
            '(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$',
            '(?m)^[\t ]*@since[\t ]+2026-08-20[\t ]*\r?$',
            '(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$'
        )
        DeclarationPattern = '(?ms)/\*/\{Protheus\.doc\}(?<body>.*?)\*/[\t \r\n]*^[\t ]*@Get[\t ]*\([\t ]*;[^\r\n]*\r?$.*?^[\t ]*\)[\t ]*\r?$[\t \r\n]*^[\t ]*User[\t ]+Function[\t ]+HloApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$'
        Patterns = @(
            '(?m)^[\t ]*#include[\t ]+"tlpp-core\.th"[\t ]*\r?$',
            '(?m)^[\t ]*#include[\t ]+"tlpp-rest\.th"[\t ]*\r?$',
            '(?m)^[\t ]*@Get[\t ]*\([\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*\bendpoint[\t ]*=[\t ]*"/api/v1/hello"[^\r\n]*\r?$',
            '(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*\btitle[\t ]*=[\t ]*"Hello World"[^\r\n]*\r?$',
            '(?m)^[\t ]*description[\t ]*=[\t ]*"Retorna uma mensagem Hello World gerada por um endpoint TL\+\+\."[\t ]*,?[\t ]*;?[\t ]*\r?$',
            '(?m)^[\t ]*User[\t ]+Function[\t ]+HloApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$',
            '(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*JsonObject[\t ]*\(\)[\t ]*:[\t ]*New[\t ]*\(\)',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Hello World"[\t ]*\r?$',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"language"[\t ]*\][\t ]*:=[\t ]*"TL\+\+"[\t ]*\r?$',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"success"[\t ]*\r?$',
            '(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*oRest[\t ]*:[\t ]*SetKeyHeaderResponse[\t ]*\([\t ]*"Content-Type"[\t ]*,[\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Return[\t ]+oRest[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$'
        )
        Responses = @(
            @{
                StatusCode = 200
                Description = "Hello World retornado com sucesso."
            }
        )
    }
    export = @{
        Path = Join-Path $repoRoot "examples\hello-world\openapi-export.tlpp"
        DocumentationPatterns = @(
            '(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$',
            '(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$',
            '(?m)^[\t ]*@since[\t ]+2026-08-20[\t ]*\r?$',
            '(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$'
        )
        DeclarationPattern = '(?ms)/\*/\{Protheus\.doc\}(?<body>.*?)\*/[\t \r\n]*^[\t ]*@Get[\t ]*\([\t ]*;[^\r\n]*\r?$.*?^[\t ]*\)[\t ]*\r?$[\t \r\n]*^[\t ]*User[\t ]+Function[\t ]+GenOApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$'
        Patterns = @(
            '(?m)^[\t ]*#include[\t ]+"tlpp-core\.th"[\t ]*\r?$',
            '(?m)^[\t ]*#include[\t ]+"tlpp-rest\.th"[\t ]*\r?$',
            '(?m)^[\t ]*@Get[\t ]*\([\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*endpoint[\t ]*=[\t ]*"/api/v1/openapi/export"[\t ]*,?[\t ]*;?[\t ]*\r?$',
            '(?m)^[\t ]*title[\t ]*=[\t ]*"Exportar OpenAPI"[\t ]*,?[\t ]*;?[\t ]*\r?$',
            '(?m)^[\t ]*description[\t ]*=[\t ]*"Gera o documento OpenAPI das rotas descobertas na porta REST 8084\."[\t ]*,?[\t ]*;?[\t ]*\r?$',
            '(?m)^[\t ]*User[\t ]+Function[\t ]+GenOApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$',
            '(?m)^[\t ]*Local[\t ]+lOk[\t ]*:=[\t ]*\.T\.[\t ]+as[\t ]+Logical[\t ]*\r?$',
            '(?m)^[\t ]*Local[\t ]+jResp[\t ]*:=[\t ]*JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([\t ]*\)[\t ]+as[\t ]+Json[\t ]*\r?$',
            '(?ms)^[\t ]*Begin[\t ]+Sequence[\t ]*\r?$[\t \r\n]*^[\t ]*tlpp\.doc\.generate[\t ]*\([\t ]*"swagger"[\t ]*,[\t ]*"hello_openapi"[\t ]*,[\t ]*\{[\t ]*8084[\t ]*\}[\t ]*,[\t ]*\{[\t ]*"pt-br"[\t ]*\}[\t ]*\)[\t ]*\r?$[\t \r\n]*^[\t ]*Recover[\t ]*\r?$[\t \r\n]*^[\t ]*lOk[\t ]*:=[\t ]*\.F\.[\t ]*\r?$[\t \r\n]*^[\t ]*End[\t ]+Sequence[\t ]*\r?$',
            '(?ms)^[\t ]*If[\t ]+lOk[\t ]*\r?$[\t \r\n]*^[\t ]*jResp[\t ]*\[[\t ]*"success"[\t ]*\][\t ]*:=[\t ]*\.T\.[\t ]*\r?$[\t \r\n]*^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Exportação OpenAPI solicitada com sucesso\."[\t ]*\r?$[\t \r\n]*^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)[\t ]*\r?$[\t \r\n]*^[\t ]*Else[\t ]*\r?$[\t \r\n]*^[\t ]*jResp[\t ]*\[[\t ]*"success"[\t ]*\][\t ]*:=[\t ]*\.F\.[\t ]*\r?$[\t \r\n]*^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Falha ao solicitar a exportação OpenAPI\."[\t ]*\r?$[\t \r\n]*^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*500[\t ]*\)[\t ]*\r?$[\t \r\n]*^[\t ]*EndIf[\t ]*\r?$',
            '(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*oRest[\t ]*:[\t ]*SetKeyHeaderResponse[\t ]*\([\t ]*"Content-Type"[\t ]*,[\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Return[\t ]+oRest[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$'
        )
        Responses = @(
            @{
                StatusCode = 200
                Description = "Exportação solicitada com sucesso."
            },
            @{
                StatusCode = 500
                Description = "Falha ao solicitar a exportação."
            }
        )
    }
    advpl = @{
        Path = Join-Path $repoRoot "examples\hello-world\hello-api-advpl.prw"
        DocumentationPatterns = @(
            '(?m)^/\*/\{Protheus\.doc\} HloAdv[\t ]*\r?$',
            '(?m)^[\t ]*@type[\t ]+wsrestful[\t ]*\r?$',
            '(?m)^/\*/\{Protheus\.doc\} HloAdv::Hello[\t ]*\r?$',
            '(?m)^[\t ]*@type[\t ]+method[\t ]*\r?$',
            '(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$',
            '(?m)^[\t ]*@since[\t ]+2026-08-21[\t ]*\r?$',
            '(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$'
        )
        DeclarationPattern = '(?ms)(?<body>/\*/\{Protheus\.doc\} HloAdv.*?)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]+WSSERVICE[\t ]+HloAdv[\t ]*\r?$'
        Patterns = @(
            '(?m)^[\t ]*#include[\t ]+"totvs\.ch"[\t ]*\r?$',
            '(?m)^[\t ]*#include[\t ]+"restful\.ch"[\t ]*\r?$',
            '(?m)^[\t ]*WSRESTFUL[\t ]+HloAdv[\t ]+DESCRIPTION[\t ]+"Hello World AdvPL"[\t ]+FORMAT[\t ]+APPLICATION_JSON[\t ]*\r?$',
            '(?m)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*DESCRIPTION[\t ]+"Retorna uma mensagem Hello World gerada por um endpoint AdvPL\."[\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*WSSYNTAX[\t ]+"/api/v1/hello-advpl"[\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*PATH[\t ]+"/api/v1/hello-advpl"[\t ]*;[\t ]*\r?$',
            '(?m)^[\t ]*PRODUCES[\t ]+APPLICATION_JSON[\t ]*\r?$',
            '(?m)^[\t ]*END[\t ]+WSRESTFUL[\t ]*\r?$',
            '(?m)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]+WSSERVICE[\t ]+HloAdv[\t ]*\r?$',
            '(?m)^[\t ]*Local[\t ]+lRet[\t ]*:=[\t ]*\.T\.[\t ]*\r?$',
            '(?m)^[\t ]*Local[\t ]+jResp[\t ]*:=[\t ]*JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Local[\t ]+cResp[\t ]*:=[\t ]*""[\t ]*\r?$',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Hello World"[\t ]*\r?$',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"language"[\t ]*\][\t ]*:=[\t ]*"AdvPL"[\t ]*\r?$',
            '(?m)^[\t ]*jResp[\t ]*\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"success"[\t ]*\r?$',
            '(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Self[\t ]*:[\t ]*SetContentType[\t ]*\([\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Self[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$',
            '(?m)^[\t ]*Return[\t ]+lRet[\t ]*\r?$'
        )
        Responses = @()
    }
}

$contract = $contracts[$Target]

if (-not (Test-Path -LiteralPath $contract.Path)) {
    throw "Fonte não encontrado: $($contract.Path)"
}

$bytes = [System.IO.File]::ReadAllBytes($contract.Path)
$hasUtf8Bom = $bytes.Length -ge 3 -and
    $bytes[0] -eq 0xEF -and
    $bytes[1] -eq 0xBB -and
    $bytes[2] -eq 0xBF
$hasUtf16LeBom = $bytes.Length -ge 2 -and
    $bytes[0] -eq 0xFF -and
    $bytes[1] -eq 0xFE
$hasUtf16BeBom = $bytes.Length -ge 2 -and
    $bytes[0] -eq 0xFE -and
    $bytes[1] -eq 0xFF
$hasUtf32LeBom = $bytes.Length -ge 4 -and
    $bytes[0] -eq 0xFF -and
    $bytes[1] -eq 0xFE -and
    $bytes[2] -eq 0x00 -and
    $bytes[3] -eq 0x00
$hasUtf32BeBom = $bytes.Length -ge 4 -and
    $bytes[0] -eq 0x00 -and
    $bytes[1] -eq 0x00 -and
    $bytes[2] -eq 0xFE -and
    $bytes[3] -eq 0xFF

if ($hasUtf8Bom -or $hasUtf16LeBom -or $hasUtf16BeBom -or
    $hasUtf32LeBom -or $hasUtf32BeBom) {
    throw "O fonte possui BOM não permitido: $($contract.Path)"
}

$hasNonAscii = $false

foreach ($byte in $bytes) {
    if ($byte -gt 0x7F) {
        $hasNonAscii = $true
        break
    }
}

if ($hasNonAscii) {
    # CP1252 e UTF-8 sem BOM podem produzir sequências de bytes ambíguas.
    # Esta heurística complementa, mas não substitui, a conversão controlada
    # pelo script oficial de encoding usado na geração dos fontes Protheus.
    $isUtf8 = $false
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

    try {
        $null = $utf8Strict.GetString($bytes)
        $isUtf8 = $true
    } catch [System.Text.DecoderFallbackException] {
        $isUtf8 = $false
    }

    if ($isUtf8) {
        throw "O fonte está em UTF-8 sem BOM: $($contract.Path)"
    }
}

$content = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)

$documentation = $null

if ($contract.DocumentationPatterns.Count -gt 0) {
    $documentation = [System.Text.RegularExpressions.Regex]::Match(
        $content,
        $contract.DeclarationPattern
    )

    if (-not $documentation.Success) {
        throw "Sequência ProtheusDOC, annotation e função ausente em ${Target}."
    }

    foreach ($pattern in $contract.DocumentationPatterns) {
        if ($documentation.Groups["body"].Value -notmatch $pattern) {
            throw "Contrato ProtheusDOC ausente em ${Target}: $pattern"
        }
    }
}

# Remoção simples para esta POC. Não substitui um parser TL++ e pressupõe
# que os valores contratuais não contenham marcadores de comentário em strings.
$validationContent = [System.Text.RegularExpressions.Regex]::Replace(
    $content,
    '(?s)/\*.*?\*/',
    ''
)
$validationContent = [System.Text.RegularExpressions.Regex]::Replace(
    $validationContent,
    '(?m)//[^\r\n]*',
    ''
)

foreach ($pattern in $contract.Patterns) {
    if ($validationContent -notmatch $pattern) {
        throw "Contrato ausente em ${Target}: $pattern"
    }
}

if ($contract.Responses.Count -gt 0) {
    $responsesProperty = [System.Text.RegularExpressions.Regex]::Matches(
        $validationContent,
        '(?m)^[\t ]*responses[\t ]*=[\t ]*''(?<json>[^''\r\n]*)''[\t ]*;?[\t ]*,?[\t ]*\r?$'
    )

    if ($responsesProperty.Count -ne 1) {
        throw "Propriedade responses ausente ou duplicada em ${Target}."
    }

    $responsesJson = $responsesProperty[0].Groups["json"].Value.Trim()

    if (-not ($responsesJson.StartsWith("[") -and $responsesJson.EndsWith("]"))) {
        throw "responses deve ser um array JSON em ${Target}."
    }

    try {
        $parsedResponses = $responsesJson | ConvertFrom-Json
    } catch {
        throw "JSON inválido em responses de ${Target}: $($_.Exception.Message)"
    }

    if ($parsedResponses -isnot [System.Array]) {
        throw "responses deve ser um array JSON em ${Target}."
    }

    $responses = [object[]]$parsedResponses

    if ($responses.Count -ne $contract.Responses.Count) {
        throw "Quantidade de responses inválida em ${Target}: esperado $($contract.Responses.Count), obtido $($responses.Count)."
    }

    for ($index = 0; $index -lt $contract.Responses.Count; $index++) {
        $expected = $contract.Responses[$index]
        $actual = $responses[$index]

        if ($actual -isnot [PSCustomObject] -or $actual -is [System.Array]) {
            throw "Response inválido em ${Target} na posição ${index}: esperado um objeto JSON."
        }

        $propertyNames = @($actual.PSObject.Properties.Name)

        if ($propertyNames -cnotcontains "statusCode" -or
            $propertyNames -cnotcontains "description") {
            throw "Response inválido em ${Target} na posição ${index}: propriedades obrigatórias ausentes."
        }

        if ($propertyNames.Count -ne 2) {
            throw "Response inválido em ${Target} na posição ${index}: propriedades extras não são permitidas."
        }

        $statusCodeIsInteger = $actual.statusCode -is [int] -or
            $actual.statusCode -is [long]

        if (-not $statusCodeIsInteger -or
            $actual.statusCode -ne $expected.StatusCode -or
            $actual.description -cne $expected.Description) {
            throw "Response inválido em ${Target} na posição ${index}: esperado statusCode=$($expected.StatusCode) e description='$($expected.Description)'."
        }
    }
}

Write-Output "Contrato $Target válido."
