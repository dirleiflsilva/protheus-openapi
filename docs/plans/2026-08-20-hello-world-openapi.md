# Hello World TL++ com OpenAPI — Plano de Implementação

> **For Claude:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Criar, compilar e validar uma prova de conceito TL++ que publique um Hello World no REST 2.0 e exporte sua documentação nativa em OpenAPI JSON.

**Architecture:** Dois endpoints TL++ isolados em `examples/hello-world`: um retorna o JSON Hello World e outro aciona `tlpp.doc.generate()`. Scripts PowerShell validam os contratos dos fontes e do artefato OpenAPI; o JSON bruto permanece local e somente um snapshot sanitizado da operação Hello World é versionado.

**Tech Stack:** TL++/TLPPCore 01.06.01, REST 2.0 Protheus via `[HTTPV11]`, `tlpp-rest.th`, `JsonObject`, `tlpp.doc.generate()`, PowerShell e TDS VS Code.

---

## Premissas do ambiente

- Worktree: `D:\PROJETOS\Protheus\protheus-openapi\.worktrees\hello-world-openapi`
- Branch: `feature/hello-world-openapi`
- Release Protheus: `12.1.2510`
- AppServer: `24.3.1.5`
- LIB: `20251006 - 20250923_19220`
- TLPPCore: `01.06.01 - TLPP PANTHERA ONCA`
- Ambiente TDS/RPO: `P12_2510`
- RPO customizado: `D:\TOTVS12\Protheus12_2510\protheus\apo\REST\custom.rpo`
- REST: `http://localhost:8084/rest`
- Segurança: `SECURITY=1`; credenciais nunca serão gravadas no repositório.

## Skills obrigatórias durante a execução

- Use `@test-driven-development` antes de escrever cada comportamento.
- Use `@tlpp-rest-endpoint-generator` ao implementar os endpoints.
- Use `@utf8-to-cp1252-conversion` imediatamente após criar ou alterar cada `.tlpp`.
- Use `@advpl-tlpp-compile` para compilar no RPO REST.
- Use `@requesting-code-review` após concluir os fontes e scripts.
- Use `@verification-before-completion` antes de declarar o experimento concluído.

### Task 1: Proteger artefatos locais da exportação

**Files:**
- Modify: `.gitignore`

**Step 1: Executar a verificação que deve falhar**

Run:

```powershell
git check-ignore artifacts/local/hello_openapi_8084.json
```

Expected: exit code `1`, pois `artifacts/local/` ainda não está ignorado.

**Step 2: Adicionar a regra mínima**

Adicionar ao bloco de artefatos do `.gitignore`:

```gitignore
/artifacts/local/
```

**Step 3: Verificar a proteção**

Run:

```powershell
git check-ignore -v artifacts/local/hello_openapi_8084.json
git diff --check
```

Expected: a primeira chamada aponta a nova regra; `git diff --check` não apresenta erros.

**Step 4: Commit**

```powershell
git add .gitignore
git commit -m "chore: ignora artefatos openapi locais"
```

### Task 2: Criar o validador dos contratos TL++

**Files:**
- Create: `tests/hello-world/validate-sources.ps1`

**Step 1: Criar o teste estático**

Criar `tests/hello-world/validate-sources.ps1`:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("hello", "export")]
    [string]$Target
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

$contracts = @{
    hello = @{
        Path = Join-Path $repoRoot "examples\hello-world\hello-api.tlpp"
        Patterns = @(
            '#include "tlpp-core\.th"',
            '#include "tlpp-rest\.th"',
            'endpoint="/api/v1/hello"',
            'title="Hello World"',
            'responses=',
            'JsonObject\(\):New\(\)',
            '"message"',
            '"language"',
            '"status"',
            'Content-Type',
            'application/json'
        )
    }
    export = @{
        Path = Join-Path $repoRoot "examples\hello-world\openapi-export.tlpp"
        Patterns = @(
            '#include "tlpp-core\.th"',
            '#include "tlpp-rest\.th"',
            'endpoint="/api/v1/openapi/export"',
            'tlpp\.doc\.generate\(',
            '"json"',
            '"hello_openapi"',
            '\{8084\}',
            '"pt-br"',
            'Content-Type',
            'application/json'
        )
    }
}

$contract = $contracts[$Target]

if (-not (Test-Path -LiteralPath $contract.Path)) {
    throw "Fonte não encontrado: $($contract.Path)"
}

$content = Get-Content -LiteralPath $contract.Path -Raw -Encoding Default

foreach ($pattern in $contract.Patterns) {
    if ($content -notmatch $pattern) {
        throw "Contrato ausente em $Target: $pattern"
    }
}

$bytes = [System.IO.File]::ReadAllBytes($contract.Path)
$hasUtf8Bom = $bytes.Length -ge 3 -and
    $bytes[0] -eq 0xEF -and
    $bytes[1] -eq 0xBB -and
    $bytes[2] -eq 0xBF

if ($hasUtf8Bom) {
    throw "O fonte possui BOM UTF-8: $($contract.Path)"
}

Write-Output "Contrato $Target válido."
```

**Step 2: Executar o teste antes dos fontes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
```

Expected: FAIL com `Fonte não encontrado`.

**Step 3: Verificar a sintaxe do script**

Run:

```powershell
$errors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path "tests/hello-world/validate-sources.ps1"),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { throw ($errors | Out-String) }
```

Expected: nenhuma exceção.

**Step 4: Manter o teste sem commit até ficar verde**

Não criar commit nesta etapa: o contrato `hello` ainda falha intencionalmente. O teste será versionado junto com a primeira implementação que o tornar verde.

### Task 3: Implementar o endpoint Hello World

**Files:**
- Create: `examples/hello-world/hello-api.tlpp`
- Test: `tests/hello-world/validate-sources.ps1`

**Step 1: Confirmar o teste vermelho**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
```

Expected: FAIL porque `hello-api.tlpp` ainda não existe.

**Step 2: Criar a implementação mínima**

Criar `examples/hello-world/hello-api.tlpp`:

```tlpp
#include "tlpp-core.th"
#include "tlpp-rest.th"

/*/{Protheus.doc}
    Endpoint mínimo para validar o REST TL++ e sua documentação nativa.
    @type function
    @author Dirlei Silva
    @since 2026-08-20
    @return logical, Resultado do envio da resposta REST
*/
@Get(;
    endpoint="/api/v1/hello",;
    title="Hello World",;
    description="Retorna uma mensagem Hello World gerada por um endpoint TL++.",;
    responses='[{"statusCode":200,"description":"Hello World retornado com sucesso."}]';
)
User Function HloApi() as Logical

    Local jResp := JsonObject():New() as Json
    Local cResp := "" as Character

    jResp["message"]  := "Hello World"
    jResp["language"] := "TL++"
    jResp["status"]   := "success"
    cResp := jResp:ToJson()

    oRest:SetStatusCode(200)
    oRest:SetKeyHeaderResponse("Content-Type", "application/json")

Return oRest:SetResponse(cResp)
```

**Step 3: Converter o encoding**

Invocar `@utf8-to-cp1252-conversion` para converter somente:

```text
examples/hello-world/hello-api.tlpp
```

Expected: Windows-1252 sem BOM.

**Step 4: Executar o teste verde**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
```

Expected: `Contrato hello válido.`

**Step 5: Revisar o fonte**

Run:

```powershell
rg -n "(?i)^\s*Function\s|IIF\(|ConOut|MsgAlert|GetMV|RpcSetEnv|StaticCall" examples/hello-world/hello-api.tlpp
```

Expected: nenhum resultado; `User Function` não corresponde à busca por uma declaração isolada `Function`.

**Step 6: Commit**

```powershell
git add tests/hello-world/validate-sources.ps1 examples/hello-world/hello-api.tlpp
git commit -m "feat: adiciona endpoint hello world em tlpp"
```

### Task 4: Implementar o acionador da exportação OpenAPI

**Files:**
- Create: `examples/hello-world/openapi-export.tlpp`
- Test: `tests/hello-world/validate-sources.ps1`

**Step 1: Confirmar o teste vermelho**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
```

Expected: FAIL porque `openapi-export.tlpp` ainda não existe.

**Step 2: Criar a implementação mínima**

Criar `examples/hello-world/openapi-export.tlpp`:

```tlpp
#include "tlpp-core.th"
#include "tlpp-rest.th"

/*/{Protheus.doc}
    Aciona a exportação experimental da documentação OpenAPI nativa.
    @type function
    @author Dirlei Silva
    @since 2026-08-20
    @return logical, Resultado do envio da resposta REST
*/
@Get(;
    endpoint="/api/v1/openapi/export",;
    title="Exportar OpenAPI",;
    description="Gera o documento OpenAPI das rotas descobertas na porta REST 8084.",;
    responses='[{"statusCode":200,"description":"Exportação solicitada com sucesso."},{"statusCode":500,"description":"Falha ao solicitar a exportação."}]';
)
User Function GenOApi() as Logical

    Local lOk   := .T. as Logical
    Local jResp := JsonObject():New() as Json
    Local cResp := "" as Character

    Begin Sequence
        tlpp.doc.generate("json", "hello_openapi", {8084}, {"pt-br"})
    Recover
        lOk := .F.
    End Sequence

    If lOk
        jResp["success"] := .T.
        jResp["message"] := "Exportação OpenAPI solicitada com sucesso."
        oRest:SetStatusCode(200)
    Else
        jResp["success"] := .F.
        jResp["message"] := "Falha ao solicitar a exportação OpenAPI."
        oRest:SetStatusCode(500)
    EndIf

    cResp := jResp:ToJson()
    oRest:SetKeyHeaderResponse("Content-Type", "application/json")

Return oRest:SetResponse(cResp)
```

**Step 3: Converter o encoding**

Invocar `@utf8-to-cp1252-conversion` para converter somente:

```text
examples/hello-world/openapi-export.tlpp
```

Expected: Windows-1252 sem BOM.

**Step 4: Executar o teste verde**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
```

Expected: `Contrato export válido.`

**Step 5: Revisar o fonte**

Run:

```powershell
rg -n "(?i)^\s*Function\s|IIF\(|ConOut|MsgAlert|GetMV|RpcSetEnv|StaticCall" examples/hello-world/openapi-export.tlpp
```

Expected: nenhum resultado; `User Function` não corresponde à busca por uma declaração isolada `Function`.

**Step 6: Commit**

```powershell
git add examples/hello-world/openapi-export.tlpp
git commit -m "feat: adiciona exportacao openapi nativa"
```

### Task 5: Criar o validador e extrator do documento OpenAPI

**Files:**
- Create: `scripts/validate-hello-openapi.ps1`
- Create: `scripts/extract-hello-openapi.ps1`
- Create: `tests/hello-world/fixtures/openapi-without-hello.json`
- Create: `tests/hello-world/fixtures/openapi-with-hello.json`

**Step 1: Criar fixtures vermelho e verde**

Criar `tests/hello-world/fixtures/openapi-without-hello.json`:

```json
{
  "openapi": "3.0.0",
  "info": { "title": "Fixture inválida", "version": "1.0.0" },
  "paths": {}
}
```

Criar `tests/hello-world/fixtures/openapi-with-hello.json`:

```json
{
  "openapi": "3.0.0",
  "info": { "title": "Fixture válida", "version": "1.0.0" },
  "paths": {
    "/api/v1/hello": {
      "get": {
        "title": "Hello World",
        "description": "Retorna uma mensagem Hello World gerada por um endpoint TL++.",
        "responses": {
          "200": { "description": "Hello World retornado com sucesso." }
        }
      }
    }
  }
}
```

**Step 2: Criar o validador**

Criar `scripts/validate-hello-openapi.ps1`:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
$document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json

$specVersion = $document.openapi
if (-not $specVersion) {
    $specVersion = $document.swagger
}

if (-not $specVersion) {
    throw "O documento não declara openapi nem swagger."
}

$pathNames = @($document.paths.PSObject.Properties.Name)
$helloPath = @($pathNames | Where-Object { $_ -match "/api/v1/hello$" })

if ($helloPath.Count -ne 1) {
    throw "Esperado exatamente um path terminado em /api/v1/hello; encontrado: $($helloPath.Count)."
}

$pathItem = $document.paths.PSObject.Properties[$helloPath[0]].Value
if (-not $pathItem.get) {
    throw "A operação GET não foi encontrada em $($helloPath[0])."
}

$operation = $pathItem.get
$title = $operation.title
if (-not $title) {
    $title = $operation.summary
}

if ($title -ne "Hello World") {
    throw "Título inesperado: $title"
}

if (-not $operation.responses.PSObject.Properties["200"]) {
    throw "A resposta HTTP 200 não foi documentada."
}

Write-Output "OpenAPI válido para o experimento. Versão: $specVersion; path: $($helloPath[0])."
```

**Step 3: Criar o extrator sanitizado**

Criar `scripts/extract-hello-openapi.ps1`:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$document = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pathNames = @($document.paths.PSObject.Properties.Name)
$helloPath = @($pathNames | Where-Object { $_ -match "/api/v1/hello$" })

if ($helloPath.Count -ne 1) {
    throw "Não foi possível isolar exatamente um path Hello World."
}

$paths = [ordered]@{}
$paths[$helloPath[0]] = $document.paths.PSObject.Properties[$helloPath[0]].Value

$snapshot = [ordered]@{}
if ($document.openapi) {
    $snapshot["openapi"] = $document.openapi
} elseif ($document.swagger) {
    $snapshot["swagger"] = $document.swagger
}

$snapshot["info"] = $document.info
$snapshot["paths"] = $paths

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$snapshot | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Snapshot criado em $OutputPath"
```

**Step 4: Confirmar o teste vermelho**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/hello-world/fixtures/openapi-without-hello.json
```

Expected: FAIL com `Esperado exatamente um path`.

**Step 5: Confirmar o teste verde**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/hello-world/fixtures/openapi-with-hello.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-hello-openapi.ps1 -InputPath tests/hello-world/fixtures/openapi-with-hello.json -OutputPath artifacts/local/fixture-snapshot.json
```

Expected: validação bem-sucedida e snapshot criado dentro da pasta ignorada.

**Step 6: Commit**

```powershell
git add scripts/validate-hello-openapi.ps1 scripts/extract-hello-openapi.ps1 tests/hello-world/fixtures
git commit -m "test: valida documento openapi do hello world"
```

### Task 6: Criar o diário inicial do experimento

**Files:**
- Create: `docs/experiments/hello-world.md`

**Step 1: Criar o documento com resultados pendentes explícitos**

Criar `docs/experiments/hello-world.md` com:

```markdown
# Experimento Hello World com REST-DOC

## Ambiente

| Componente | Versão |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 - TLPP PANTHERA ONCA |
| REST | http://localhost:8084/rest |

## Objetivo

Validar a publicação de um endpoint TL++ por annotation, a documentação nativa e a exportação do documento OpenAPI em JSON.

## Resultados

- Execução de `GET /api/v1/hello`: pendente.
- Exportação com `tlpp.doc.generate()`: pendente.
- Versão declarada no documento: pendente.
- Path efetivamente gerado: pendente.
- Localização do JSON bruto: pendente.
- Visualização da documentação: pendente.

## Segurança dos artefatos

O documento bruto completo permanece em `artifacts/local/` e não é versionado. Somente o snapshot sanitizado do Hello World poderá ser incluído no repositório.

## Limitações observadas

Pendente de execução no AppServer.
```

**Step 2: Verificar o documento**

Run:

```powershell
rg -n "pendente|SECURITY|senha|token" docs/experiments/hello-world.md
git diff --check
```

Expected: somente estados pendentes intencionais; nenhuma senha ou token.

**Step 3: Commit**

```powershell
git add docs/experiments/hello-world.md
git commit -m "docs: inicia diario do experimento openapi"
```

### Task 7: Compilar os fontes TL++ no RPO REST

**Files:**
- Compile: `examples/hello-world/hello-api.tlpp`
- Compile: `examples/hello-world/openapi-export.tlpp`

**Step 1: Verificar encoding e contratos antes da compilação**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
```

Expected: ambos os contratos válidos.

**Step 2: Compilar com o fluxo oficial**

Invocar `@advpl-tlpp-compile`, selecionar o servidor correspondente ao ambiente `P12_2510` e compilar os dois fontes no `custom.rpo` REST. A senha deverá ser digitada pelo usuário diretamente no VS Code e não será visível ao agente.

Expected: compilação dos dois fontes concluída sem erro.

**Step 3: Registrar evidências**

Anotar no diário:

- data e hora;
- servidor selecionado;
- resultado de cada compilação;
- eventuais warnings;
- necessidade ou não de reiniciar/recarregar o REST.

Não declarar sucesso se a ferramenta não apresentar evidência de compilação concluída.

### Task 8: Testar os endpoints no REST 2.0

**Files:**
- Update: `docs/experiments/hello-world.md`

**Step 1: Testar o Hello World com autenticação interativa**

Run em um terminal local, substituindo apenas o usuário; `curl` solicitará a senha sem gravá-la no comando:

```powershell
curl.exe --user "USUARIO_PROTHEUS" --include "http://localhost:8084/rest/api/v1/hello"
```

Expected:

- HTTP `200`;
- `Content-Type: application/json`;
- JSON com `message=Hello World`, `language=TL++` e `status=success`.

**Step 2: Acionar a exportação**

Run:

```powershell
curl.exe --user "USUARIO_PROTHEUS" --include "http://localhost:8084/rest/api/v1/openapi/export"
```

Expected: HTTP `200` e JSON indicando solicitação bem-sucedida. Se retornar `500`, coletar somente logs não sensíveis e aplicar `@systematic-debugging` antes de alterar o fonte.

**Step 3: Registrar os resultados**

Atualizar `docs/experiments/hello-world.md` com status HTTP, cabeçalhos relevantes e corpo observado, sem registrar credenciais ou cabeçalhos de autorização.

### Task 9: Localizar, validar e sanitizar o JSON real

**Files:**
- Local only: `artifacts/local/hello_openapi_<porta>.json`
- Create after runtime: `examples/hello-world/snapshots/hello-openapi.json`
- Update: `docs/experiments/hello-world.md`

**Step 1: Localizar o arquivo gerado**

Run:

```powershell
Get-ChildItem -Path "D:\TOTVS12\Protheus12_2510" -Recurse -Filter "hello_openapi*.json" -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime
```

Expected: ao menos um arquivo recente. Se não houver resultado, pesquisar também pelo prefixo sem extensão e consultar o log do AppServer antes de modificar o código.

**Step 2: Copiar o bruto para a pasta ignorada**

Run, substituindo `CAMINHO_GERADO` pelo resultado real verificado:

```powershell
New-Item -ItemType Directory -Path "artifacts/local" -Force | Out-Null
Copy-Item -LiteralPath "CAMINHO_GERADO" -Destination "artifacts/local/hello-openapi.json"
```

Expected: `git status --short` não lista o JSON bruto.

**Step 3: Validar o documento real**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path artifacts/local/hello-openapi.json
```

Expected: versão e path real informados pelo validador.

**Step 4: Extrair o snapshot sanitizado**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-hello-openapi.ps1 -InputPath artifacts/local/hello-openapi.json -OutputPath examples/hello-world/snapshots/hello-openapi.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path examples/hello-world/snapshots/hello-openapi.json
```

Expected: snapshot contém somente o path Hello World e passa no validador.

**Step 5: Revisar dados antes do commit**

Run:

```powershell
rg -n -i "authorization|password|token|secret|clientid|clientsecret" examples/hello-world/snapshots/hello-openapi.json
```

Expected: nenhum segredo ou esquema interno inesperado. Revisar manualmente todo o snapshot mesmo quando a busca estiver vazia.

**Step 6: Commit**

```powershell
git add examples/hello-world/snapshots/hello-openapi.json docs/experiments/hello-world.md
git commit -m "docs: registra resultado do hello world openapi"
```

### Task 10: Visualizar a documentação nativa

**Files:**
- Update: `docs/experiments/hello-world.md`

**Step 1: Abrir o monitor TLPPCore**

Abrir no navegador:

```text
http://localhost:32033/api
```

Se `[APP_MONITOR]` definir outra porta ou SSL, usar a URL efetiva registrada no ambiente.

**Step 2: Confirmar a operação**

No módulo de documentação/listagem de endpoints, localizar `/api/v1/hello` e verificar:

- verbo GET;
- título;
- descrição;
- resposta 200;
- representação do path sob a base `/rest`.

**Step 3: Registrar evidências sem dados sensíveis**

Atualizar o diário com a URL do monitor, o resultado da renderização e qualquer diferença entre a UI, o JSON e o fonte. Não versionar captura que exponha outras APIs do ambiente.

**Step 4: Commit**

```powershell
git add docs/experiments/hello-world.md
git commit -m "docs: conclui observacoes do rest-doc"
```

### Task 11: Revisão e verificação final

**Files:**
- Review: `.gitignore`
- Review: `examples/hello-world/hello-api.tlpp`
- Review: `examples/hello-world/openapi-export.tlpp`
- Review: `examples/hello-world/snapshots/hello-openapi.json`
- Review: `scripts/*.ps1`
- Review: `tests/hello-world/**`
- Review: `docs/experiments/hello-world.md`

**Step 1: Solicitar revisão de código**

Invocar `@requesting-code-review` e tratar apenas achados confirmados. Se houver feedback, usar `@receiving-code-review` antes de alterar o código.

**Step 2: Executar todas as verificações locais**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/hello-world/fixtures/openapi-with-hello.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path examples/hello-world/snapshots/hello-openapi.json
git diff --check
git status --short
```

Expected: validadores aprovados, nenhum erro de whitespace e worktree limpa.

**Step 3: Confirmar verificações de integração**

Antes de concluir, confirmar evidências recentes para:

- compilação dos dois fontes no RPO REST;
- HTTP 200 do Hello World;
- HTTP 200 do acionador de exportação;
- JSON real localizado e validado;
- operação renderizada na documentação nativa;
- snapshot revisado sem dados sensíveis.

**Step 4: Aplicar a verificação de completude**

Invocar `@verification-before-completion` e comparar o resultado com o desenho `docs/plans/2026-08-20-hello-world-openapi-design.md`.

Formato do relatório final:

- ✅ Implementado e validado.
- ⚠️ Limitação documentada.
- 🔄 Mantido como contingência `[HTTPSERVER]`.
- ❓ Pendente de confirmação no ambiente.

**Step 5: Commit final somente se necessário**

Se a revisão exigir ajustes documentais ou de código:

```powershell
git add <arquivos-ajustados>
git commit -m "chore: finaliza prova de conceito openapi"
```

Não criar commit vazio.
