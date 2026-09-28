# Adaptador para endpoints AdvPL — Contexto e Decisões

**Feature:** openapi-advpl-adapter  
**Fase do roadmap:** Fase 4  
**Data:** 2026-09-26  
**Referência:** commit 86ce4a0 (Fase 3 concluída)

---

## Premissas verificadas antes de projetar o adaptador

### 1. Mecanismo de descoberta: parsing textual, não reflection

A Fase 3 descobriu endpoints TL++ em **runtime** via `Reflection.getFunctionsByAnnotation()` — uma API do `tlppCore` que enumera funções anotadas no RPO compilado.

`WSRESTFUL` é uma estrutura **sintática** expandida pelo pré-processador AdvPL a partir de macros de `restful.ch`. Após a compilação, o RPO contém a classe gerada, mas **não existe API de reflection ou enumeração equivalente** para serviços WSRESTFUL: nenhuma chamada do tipo `GetWsClass()`, `WsGetClass()`, `GetRestService()` ou similar foi encontrada em nenhum dos arquivos `.prw` das fontes padrão do Protheus (`D:\PROJETOS\Protheus\TOTVS\P12.1.2510-202505\Master\Fontes`). O grep retornou zero resultados para todas essas hipóteses.

**Decisão confirmada:** o adaptador AdvPL lê e tokeniza o **texto-fonte** (`.prw`/`.prg`) — não faz chamadas a APIs do `tlppCore` em runtime. Isso é uma diferença arquitetural fundamental em relação à Fase 3.

**Implicação para o fluxo de uso:** o adaptador recebe o caminho do arquivo-fonte como entrada, não um nome de fonte no RPO.

**Restrição de plataforma confirmada por execução real (2026-09-28, spike T1):** as funções `User Function` expostas via `@Get`/`@Post` (`tlpp-rest`) rodam como **job HTTP** (`[HTTPJOB] MAIN=HTTP_START` no `appserver.ini`) — um job é "um programa sem interface remota". Nesse contexto, `MemoRead()` e demais funções de manipulação de arquivo só enxergam caminhos **relativos ao `RootPath`** do ambiente (parâmetro `RootPath=` do `appserver.ini`, ex.: `D:\TOTVS12\Protheus12_2510\protheus_data`), sem letra de drive. Um caminho absoluto (`d:/pasta/arquivo.prw`) é tradicionalmente interpretado como "estação do SmartClient" — que não existe em contexto de job — e `MemoRead()` retorna string vazia **silenciosamente**, sem lançar exceção. Confirmado em teste real: `MemoRead()` com caminho absoluto → `""`; o mesmo arquivo copiado para dentro do `RootPath` e referenciado por caminho relativo (`/openapi-advpl-adapter/hello-advpl.prw`) → leitura bem-sucedida (`textLen` bateu exatamente com o tamanho do arquivo).

**Implicação para o design do adaptador:** `OApiWsrBuild::build(oDoc, cFilePath)` (e `OApiWsrParser::parse(cFilePath)`) devem documentar `cFilePath` como **caminho relativo ao `RootPath` do ambiente**, não um caminho de disco arbitrário. Isso é uma limitação de plataforma, não uma escolha de design — não há solução alternativa dentro do escopo desta fase (copiar/publicar o fonte-alvo para dentro do `RootPath` é responsabilidade de quem usa o adaptador, análogo a como o exemplo-alvo `hello-advpl.prw` precisou ser copiado para `protheus_data\openapi-advpl-adapter\` para o spike funcionar).

### 2. Exemplo-alvo existente

`examples/hello-world/hello-api-advpl.prw` já existe no projeto com a sintaxe mínima de `WSRESTFUL`. Ele usa:

- `WSRESTFUL api DESCRIPTION "Hello World AdvPL" FORMAT APPLICATION_JSON`
- `WSMETHOD GET Hello DESCRIPTION "..." WSSYNTAX "/v1/hello-advpl" PATH "/v1/hello-advpl"`
- `END WSRESTFUL`
- `WSMETHOD GET Hello WSSERVICE api`

Este arquivo é o **exemplo-alvo primário** da Fase 4 — o mesmo papel de `custom.openapi.hello.get.tlpp` / `custom.openapi.hello.post.tlpp` na Fase 3.

### 3. Sintaxe real confirmada por grep nas fontes padrão

O grep sobre +30 arquivos `.prw` reais do Protheus (`CRM`, `Gestão Agrícola`, `Framework`) revelou a seguinte gramática:

#### Bloco de definição (`WSRESTFUL ... END WSRESTFUL`)

```
WSRESTFUL <NomeServico> DESCRIPTION <literal|constante> [FORMAT <mime>] [SECURITY <n>]
    WSDATA <NomeParam> AS <STRING|CHARACTER|INTEGER|INT|BOOLEAN|ARRAY> [OPTIONAL]
    ...
    WSMETHOD <VERBO> [<NomeAcao>]
        DESCRIPTION <literal>
        WSSYNTAX <literal>
        [PATH <literal>]          // ausente na forma mais antiga
        [PRODUCES <mime>]
        [RESPONSE <tipo>]
    ...
END WSRESTFUL                     // ou ENDWSRESTFUL (sem espaço)
```

Cada cláusula do WSMETHOD dentro do bloco de definição pode aparecer **numa linha só** ou **em múltiplas linhas com continuação `;`** (padrão AdvPL/TL++).

#### Implementação dos métodos

```
WSMETHOD <VERBO> [<NomeAcao>] [PATHPARAM <lista>] [QUERYPARAM <lista>] [WSRECEIVE <lista>] (WSSERVICE|WSREST) <NomeServico>
```

As keywords de parâmetros (`PATHPARAM`, `QUERYPARAM`, `WSRECEIVE`) podem aparecer em qualquer combinação e também com continuação de linha `;`.

#### PATH — quatro padrões observados nas fontes reais

| Padrão | Exemplo | Riqueza |
|--------|---------|---------|
| Ausente (forma mais antiga) | `CRMM010`, `CRMM020` | PATH extraído do WSSYNTAX (heurística necessária) |
| PATH `""` (vazio — root do serviço) | `CRMM100`, `CRMM110` | Construir a partir do nome do serviço |
| PATH relativo com fragmento | `PATH "{code}"`, `PATH "/Fields/{EntityType}"` | Concatenar com path base do serviço |
| PATH absoluto completo | `PATH "/api/crm/v1/contactrelationship/{InternalId}"` | Usado diretamente — mais confiável |

Para a Fase 4, o **exemplo-alvo** usa PATH absoluto (`PATH "/v1/hello-advpl"`) — o caso mais simples e confiável.

#### WSDATA — tipos encontrados nos fontes reais

`STRING`, `CHARACTER`, `INTEGER`, `INT`, `BOOLEAN`, `ARRAY`

Mapeamento para OpenAPI: `STRING`/`CHARACTER` → `string`, `INTEGER`/`INT` → `integer`, `BOOLEAN` → `boolean`, `ARRAY` → `array`.

### 4. O adaptador convive com o adaptador TL++ sem conflito

- **Namespace separado:** `custom.openapi.adapter.advpl` (Fase 3 usa `custom.openapi.adapter.tlpp`).
- **Núcleo inalterado:** o adaptador AdvPL consome as mesmas classes `OApi*` de `src/core/` sem modificá-las.
- **Saída idêntica:** o `OApiDoc` produzido pelo adaptador AdvPL é estruturalmente equivalente ao produzido pelo adaptador TL++ — mesma representação intermediária, nenhuma variação de formato.

---

## Perguntas ao usuário e decisões

### D1: Exemplo-alvo — usar `hello-api-advpl.prw` existente ou criar exemplo mais rico?

**Pergunta:** O `examples/hello-world/hello-api-advpl.prw` existente tem apenas um `WSMETHOD GET` sem `WSDATA`. Para exercitar mais a feature (parâmetros WSDATA, múltiplos métodos), seria útil criar um exemplo AdvPL mais rico em `examples/openapi-advpl-adapter/`, seguindo o padrão dos exemplos anteriores.

**Decisão (2026-09-26):** Criar um **exemplo mínimo complementar** em `examples/openapi-advpl-adapter/hello-advpl.prw` com:
- um `WSMETHOD GET` com `PATH` absoluto e `WSDATA` para parâmetro query (ex.: `language`),
- um `WSMETHOD POST` com `PATH` absoluto,
para exercitar tanto a descoberta quanto a extração de `WSDATA` como `OApiParam`.

O `hello-api-advpl.prw` existente continua intacto como referência da Fase 0.

### D2: Fonte de verdade para o path de cada operação

**Pergunta:** Quando `PATH` está presente e não vazio, ele é a fonte primária. Quando ausente ou vazio, o que usar?

**Decisão (2026-09-26):**
1. `PATH` absoluto não vazio → usado diretamente (caso primário, coberto pelo exemplo-alvo).
2. `PATH` vazio `""` → construir como `/<NomeServico>` (sem path param) — registrado como limitação documentada.
3. `PATH` ausente (forma antiga) → extrair heurística do `WSSYNTAX` removendo os `{query_params}` do template — registrado como limitação documentada, fora do escopo da Fase 4.
4. `PATH` relativo (fragmento) → concatenar `/<NomeServico>` + fragmento — registrado como limitação documentada.

Para a Fase 4, **apenas o PATH absoluto é o escopo primário**. Os demais padrões são registrados como limitações.

### D3: WSDATA → OApiParam: query ou path?

**Pergunta:** `WSDATA` não distingue query de path no bloco de definição — só lista variáveis disponíveis. Como inferir `in: query` vs `in: path`?

**Decisão (2026-09-26):** Um `WSDATA` é tratado como `in: path` se seu nome aparecer entre `{...}` no `PATH` da operação; caso contrário, é tratado como `in: query`. Isso replica a heurística observada nas fontes reais (`IdContacts` em `/CRMMCONTACTS/{IdContacts, ...}` → path; demais → query). Variáveis declaradas com `PATHPARAM` na implementação confirmam a inferência mas não são necessárias para o escopo desta fase (o parser lê só o bloco de definição).

### D4: Namespace e nome de arquivo

**Decisão (2026-09-26):**
- Namespace: `custom.openapi.adapter.advpl`
- Arquivos em: `src/adapters/` (mesma pasta dos adaptadores TL++)
- Prefixo de nome: `custom.openapi.adapter.advpl.*.tlpp`
- Teste: `tests/openapi-advpl-adapter/`

### D5: Limite de escopo desta fase

**Decisão (2026-09-26):** A Fase 4 cobre o **parsing do bloco de definição** (`WSRESTFUL … END WSRESTFUL`) de um único arquivo-fonte fornecido como entrada. Não está em escopo:
- Parsing do bloco de implementação (`WSMETHOD … WSSERVICE`) para enriquecer parâmetros.
- Descoberta automática de múltiplos arquivos em um diretório.
- Suporte a PATH ausente ou PATH relativo como caso principal (apenas documentado como limitação).
- Suporte a `RESPONSE EaiObj` / tipos não-primitivos como schema.
- Parsing de constantes STR_CONST (substituídas por string vazia ou `"[STR_CONST]"` com pendência).

---

## Descobertas que influenciam o design

1. **Dois blocos distintos a parsear:** o bloco de definição (`WSRESTFUL ... END WSRESTFUL`) e os blocos de implementação (`WSMETHOD ... WSSERVICE`). O bloco de definição é suficiente para montar o `OApiDoc`; os blocos de implementação enriquecem com `PATHPARAM`/`QUERYPARAM`/`WSRECEIVE` mas são mais complexos de parsear. **A Fase 4 usa apenas o bloco de definição como fonte primária.**

2. **Dois terminadores diferentes:** `END WSRESTFUL` (com espaço) e `ENDWSRESTFUL` (sem espaço) — ambos são usados nas fontes reais. O parser deve aceitar os dois.

3. **WSDATA carrega todos os parâmetros** de um serviço de forma "flat" — sem distinguir de qual operação cada um faz parte. A associação com operações específicas é feita pelo nome aparecer no PATH ou WSSYNTAX de cada `WSMETHOD`.

4. **WSREST é sinônimo de WSSERVICE** na linha de implementação (confirmado em `AGRA030API`).

5. **Multilinha com `;`** pode aparecer tanto nas cláusulas dentro do bloco de definição quanto nas linhas de implementação.

6. **DESCRIPTION pode referenciar constante simbólica** (ex.: `STR0001`) em vez de string literal — nesses casos, o valor real não está disponível sem acesso à tabela de strings do RPO. O parser deve aceitar as duas formas e emitir pendência quando for constante.
