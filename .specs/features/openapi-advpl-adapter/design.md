# Adaptador para endpoints AdvPL — Design

**Especificação:** `.specs/features/openapi-advpl-adapter/spec.md`  
**Decisões:** `.specs/features/openapi-advpl-adapter/context.md`  
**Estado:** Ramo A (classe `Regex`) confirmado por evidência real em fontes padrão (2026-09-28, corrige decisão de 2026-09-26) — aguarda evidência de execução do spike T1

---

## Diferença arquitetural fundamental em relação à Fase 3

| | Fase 3 — Adaptador TL++ | Fase 4 — Adaptador AdvPL |
|---|---|---|
| **Mecanismo de descoberta** | Runtime — `Reflection.getFunctionsByAnnotation()` sobre o RPO compilado | Compiletime — parsing de texto-fonte (`.prw`/`.prg`) |
| **Entrada** | Lista de `cSourceName` (nomes de fonte no RPO) | Caminho de um arquivo-fonte, **relativo ao `RootPath` do ambiente** (não absoluto — ver "Restrição de plataforma: RootPath" abaixo) |
| **Fonte da verdade** | Annotation do RPO compilado | Bloco `WSRESTFUL … END WSRESTFUL` no texto-fonte |
| **API externa** | `tlppCore.Reflection.*` (confirmada por spike T1 da Fase 3) | Leitura de arquivo + regex em TL++ (a confirmar por spike T1 desta fase) |
| **Riqueza de metadados** | Alta — annotations com `endpoint`, `title`, `description`, `params`, `requestBody`, `responses` | Média — PATH, DESCRIPTION, WSDATA (tipo, opcional); sem schema de body nativo |

O núcleo `OApi*` (`src/core/`) permanece **completamente inalterado**: o adaptador AdvPL é uma camada nova, exclusivamente consumidora do núcleo, igual ao padrão da Fase 3.

---

## Arquitetura do adaptador AdvPL

O adaptador implementa três passos, análogos aos três passos da Fase 3:

```
1. Ler e pré-processar     2. Parsear e extrair       3. Montar
   o arquivo-fonte       →    metadados do bloco     →    OApiPath/OApiOper/
   (linhas físicas +          WSRESTFUL (serviço,         OApiParam
   reunião de               verbos, PATH, WSDATA)        (via API pública
   continuações ;)                                        do núcleo)
```

A montagem (passo 3) reutiliza 100 % da API pública já validada do núcleo — nenhuma classe `OApi*` ganha método novo neste incremento.

---

## Componentes do adaptador

### Namespace e localização dos arquivos

| Arquivo | Namespace | Responsabilidade |
|---------|-----------|-----------------|
| `src/adapters/custom.openapi.adapter.advpl.parser.tlpp` | `custom.openapi.adapter.advpl` | Passo 1+2: leitura do arquivo + tokenização do bloco WSRESTFUL → modelo intermediário interno |
| `src/adapters/custom.openapi.adapter.advpl.path.tlpp` | `custom.openapi.adapter.advpl` | Passo 3a: conversão de PATH + inferência de localização de parâmetro (path vs query) |
| `src/adapters/custom.openapi.adapter.advpl.build.tlpp` | `custom.openapi.adapter.advpl` | Passo 3b: montagem do `OApiDoc` a partir do modelo intermediário |
| `tests/openapi-advpl-adapter/custom.openapi.advpl.adapter.test.tlpp` | `custom.openapi.adapter.advpl` | Fixture PROBAT: `OApiWsrTst` |
| `tests/openapi-advpl-adapter/validate-sources.py` | Python | Contrato estático: encoding CP-1252 sem BOM |
| `examples/openapi-advpl-adapter/hello-advpl.prw` | AdvPL | Exemplo-alvo com WSDATA e múltiplos métodos |

O adaptador TL++ (`src/adapters/custom.openapi.adapter.*.tlpp`, namespace `custom.openapi.adapter.tlpp`) não é tocado.

---

## Detalhamento dos componentes

### Componente 1: `OApiWsrParser` (`custom.openapi.adapter.advpl.parser.tlpp`)

**Responsabilidade:** ler um arquivo-fonte, reunir continuações `;`, identificar o bloco `WSRESTFUL … END WSRESTFUL` e retornar um modelo intermediário com os metadados extraídos.

**API pública:**

```tlpp
Class OApiWsrParser
    Public Method new() Constructor
    Public Method parse(cFilePath as Character) as Array
    // Retorna: array de Json, um por serviço WSRESTFUL encontrado no arquivo.
    // Cada Json contém:
    //   "service"   : Character  — nome do serviço
    //   "desc"      : Character  — descrição (ou "" + pendência se constante)
    //   "wsdata"    : Array      — [{name, type, optional}]
    //   "methods"   : Array      — [{verb, action, desc, path, wssyntax}]
    //   "pending"   : Array      — pendências acumuladas [{context, msg}]
EndClass
```

**Algoritmo de parsing (pseudocódigo):**

```
1. MemoRead(cFilePath) → cText (texto completo)
2. Dividir por CRLF/LF em array de linhas → aLines
3. Reunir continuações: percorrer aLines; quando linha termina com ";",
   concatenar com a próxima (remover o ";") → aLogical (linhas lógicas)
4. Para cada linha lógica:
   a. Se match "^\s*WSRESTFUL\s+(\w+)\s+DESCRIPTION\s+(.+)" → início de serviço
   b. Se em modo serviço e match "^\s*WSDATA\s+(\w+)\s+AS\s+(\w+)(\s+OPTIONAL)?" → adiciona WSDATA
   c. Se em modo serviço e match "^\s*WSMETHOD\s+(GET|POST|PUT|PATCH|DELETE)\s*" → início de operação
      - extrai verbo + nome de ação opcional
      - extrai DESCRIPTION, WSSYNTAX, PATH das próximas cláusulas (podem estar na mesma linha lógica)
   d. Se match "^\s*(END\s+WSRESTFUL|ENDWSRESTFUL)\s*$" → fim do serviço atual
```

**Tratamento de DESCRIPTION:**
- String literal: `"texto"` ou `'texto'` → extrair o valor sem delimitadores
- Constante simbólica (sem aspas, ex: `STR0001`) → valor `""` + pendência `{context: "<serv>", msg: "DESCRIPTION usa constante STR0001 — valor não resolvido"}`

**Reunião de continuações `;`:**

O pré-processador AdvPL interpreta `;` ao final de linha como continuação de linha. O parser deve reconhecer esse padrão para tratar um `WSMETHOD` que se espalha por várias linhas físicas como uma única linha lógica. A reunião ocorre **antes** de qualquer extração de tokens (passo 3 acima), garantindo que regex simples operem sobre linhas lógicas completas.

---

### Componente 2: `OApiWsrPath` (`custom.openapi.adapter.advpl.path.tlpp`)

**Responsabilidade:** a partir do PATH de uma operação e da lista de WSDATA do serviço, inferir `in: path` vs `in: query` para cada parâmetro e construir os `OApiParam` correspondentes.

**API pública:**

```tlpp
Class OApiWsrPath
    Public Method new() Constructor
    Public Method toParams(cPath as Character, aWsData as Array) as Array
    // Retorna array de OApiParam (instâncias do núcleo).
    // Regra: se o nome do WSDATA aparece em {nome} no cPath → in:path, required:true
    //        caso contrário → in:query, required = !lOptional
EndClass
```

**Diferença em relação a `OApiAdpPath` da Fase 3:**

A Fase 3 (`OApiAdpPath`) converte `:nome` → `{nome}` porque annotations TL++ usam `:nome`. O `WSRESTFUL` já usa `{nome}` diretamente no `PATH` (confirmado nas fontes reais: `PATH "/api/crm/v1/contactrelationship/{InternalId}"`). Logo, **`OApiWsrPath` não precisa fazer essa conversão** — o PATH já está no formato OpenAPI. A única manipulação é o trim e remoção de aspas (se presentes) da string extraída pelo parser.

**Mapeamento de tipo WSDATA → schema OpenAPI:**

| Tipo WSDATA | Schema `type` |
|-------------|---------------|
| `STRING`, `CHARACTER` | `string` |
| `INTEGER`, `INT` | `integer` |
| `BOOLEAN` | `boolean` |
| `ARRAY` | `string` + pendência (tipo não suportado diretamente) |
| qualquer outro | `string` + pendência (tipo desconhecido) |

---

### Componente 3: `OApiWsrBuild` (`custom.openapi.adapter.advpl.build.tlpp`)

**Responsabilidade:** orquestrar os dois componentes anteriores e montar o `OApiDoc` completo chamando exclusivamente a API pública do núcleo.

**API pública:**

```tlpp
Class OApiWsrBuild
    Public Method new() Constructor
    Public Method build(oDoc as Object, cFilePath as Character) as Logical
    // Processa o arquivo, extrai todos os serviços WSRESTFUL,
    // monta OApiPath/OApiOper/OApiParam e os registra em oDoc.
    // Retorna .T. se ao menos um path foi adicionado sem erro fatal.
    // Pendências acumuladas são adicionadas ao oDoc via oDoc:addPending()
    // (mesmo mecanismo já existente no núcleo).
EndClass
```

**Fluxo interno de `build()`:**

```
1. OApiWsrParser:parse(cFilePath) → aServicos
2. Para cada serviço em aServicos:
   a. Para cada método em serviço["methods"]:
      i.  Obter PATH → se ausente/vazio: registrar pendência e pular
      ii. OApiWsrPath:toParams(cPath, aWsData) → aParams
      iii. OApiOper:new(cVerb, cDesc) → oOper
      iv. Para cada param em aParams: oOper:addParam(oParam)
      v.  Acumular {cPath, oOper} em mapa por template de path
   b. Para cada template único no mapa:
      i.  OApiPath:new(cTemplate) → oPath
      ii. Para cada oOper do template: oPath:addOper(oOper)
      iii. oDoc:addPath(oPath)  // rejeita duplicata via validação do núcleo
3. Retornar .T./.F.
```

**Agrupamento por template de path:** necessário porque `OApiDoc::addPath()` rejeita path duplicado mesmo com verbos diferentes (mesmo comportamento da Fase 3). Duas operações com `PATH "/api/v1/hello-advpl"` (GET + POST) devem ser agrupadas sob o mesmo `OApiPath` antes de chamar `addPath()`.

---

## Modelo intermediário interno

O parser retorna um `Array` de `Json` nativo. Essa estrutura é **interna ao adaptador** e nunca é exposta fora de `OApiWsrParser`. O design intencional de usar `Json` nativo (em vez de classes) minimiza dependências e mantém o adaptador coeso.

Estrutura por serviço:

```
{
  "service":  "api",                          // nome do WSRESTFUL
  "desc":     "Hello World AdvPL",            // DESCRIPTION (literal ou "")
  "wsdata": [
    { "name": "language", "type": "string", "optional": .T. }
  ],
  "methods": [
    {
      "verb":    "GET",
      "action":  "Hello",                     // NomeAcao (pode ser "")
      "desc":    "Retorna uma mensagem...",
      "path":    "/v1/hello-advpl",           // PATH extraído (ou "" se ausente)
      "wssyntax": "/v1/hello-advpl"           // WSSYNTAX (referência, não usado como path)
    },
    {
      "verb":    "POST",
      "action":  "Hello",
      "desc":    "Cria uma mensagem...",
      "path":    "/v1/hello-advpl",
      "wssyntax": "/v1/hello-advpl"
    }
  ],
  "pending": []
}
```

---

## Exemplo-alvo: `examples/openapi-advpl-adapter/hello-advpl.prw`

Arquivo novo a criar na T1/T2. Exercita:
- Um serviço `WSRESTFUL` com `FORMAT` e `DESCRIPTION` literal.
- Um `WSDATA` para parâmetro query (`language AS STRING OPTIONAL`).
- Um `WSMETHOD GET` com `PATH` absoluto sem parâmetro de path.
- Um `WSMETHOD POST` com `PATH` absoluto sem parâmetro de path.
- `END WSRESTFUL`.
- Implementação dos dois métodos (`WSMETHOD GET Hello WSSERVICE api`, `WSMETHOD POST Hello WSSERVICE api`) com lógica mínima.

Estrutura esperada no `OApiDoc`:

```
paths:
  /v1/hello-advpl:
    get:
      summary: "Retorna uma mensagem Hello World gerada por um endpoint AdvPL."
      parameters:
        - name: language
          in: query
          required: false
          schema: { type: string }
    post:
      summary: "Cria uma mensagem Hello World em AdvPL."
      parameters:
        - name: language
          in: query
          required: false
          schema: { type: string }
```

---

## Coexistência com o adaptador TL++ (Fase 3)

- **Namespaces isolados:** `custom.openapi.adapter.tlpp` (Fase 3) e `custom.openapi.adapter.advpl` (Fase 4). Nenhum `#include` cruzado necessário.
- **Mesmo `OApiDoc` como destino:** ambos os adaptadores podem popular o mesmo documento — `OApiWsrBuild::build(oDoc, cFile)` e `OApiAdpBuild::build(oDoc, aVerbs, aSources)` recebem o mesmo `oDoc` e cada um adiciona seus paths. A validação de conflito do núcleo (`OApiDoc::addPath()`) previne duplicatas entre os dois adaptadores.
- **Sem modificação do núcleo:** as 9 classes de `src/core/` permanecem intactas.

---

## API de leitura de arquivo e parsing em TL++ — Ramo A confirmado por evidência real (correção 2026-09-28)

**Correção de premissa (2026-09-28):** a pesquisa pré-spike original (2026-09-26) verificou
apenas `_binary_functions.prw`/`.tlpp` da IDE — ou seja, procurou regex como **função solta**
(binary function) e não encontrou nenhuma. Essa pesquisa estava incompleta: regex no
AdvPL/TLPP não é uma função solta, é uma **classe**. A pesquisa foi refeita nas fontes padrão
(árvore `P12.1.2510-202505\Master\Fontes`) e confirma **duas classes de regex reais em uso de
produção**:

| Classe | Namespace/uso | Confirmada em |
|--------|---------------|---------------|
| `Regex` | `Using Namespace tlpp.regex` | `TAF\Integração\TSI\TAF\TAFA633.tlpp:596-638`, `TAF\Integração\Sped\TAFA615.tlpp:1694-1732`, `Gestão de Suprimentos\Gestão de Compras\PGC\backoffice.pgc.utils.repository.tlpp:7,372,378`, `Agrodistribuidor\infra\repository\agd-repository.utils.tlpp:7` |
| `tRegex` (mais antiga, sem namespace) | uso direto | `Gestão de Licitações\GCPA200.PRW:12139` (AdvPL clássico `.PRW`), `Livros Fiscais\...\backoffice.fiscal.fisa001.utils.tlpp:76-99` (encapsulada em `RegexValids`) |

Confirmado também no TDN ("Classe RegEx", `tdn.totvs.com/display/tec/Classe+RegEx`) e no
devforum TOTVS ("tlpp - Features novas RegEx e Try...Catch. Quando sai?") — não foi possível
buscar o conteúdo completo do TDN via WebFetch (HTTP 403, provável exigência de sessão
autenticada), mas os nomes de método retornados pela busca batem com os confirmados nas
fontes reais.

**API confirmada da classe `Regex` (a usada por este adaptador):**

```tlpp
oRegex := Regex():New("")              // ou New(cPattern) direto
oRegex:SetMultiline(.T.)
oRegex:SetCaseSensitive(.F.)
oRegex:SetPattern(cPattern)            // pode ser chamado de novo no mesmo objeto
lFound := oRegex:Tokenizer(cTexto, , @aSaida)   // preenche aSaida por referencia
oRegex:ReplaceAll(@cVar, cSubstituto)  // substituicao in-place, confirmada em producao
FWFreeObj(oRegex)
```

`SetPattern()` reaproveitado no mesmo objeto (sem `New()` a cada padrão) é confirmado em
`TAFA615.tlpp:1726-1728`, dentro de um `For`.

**CONFIRMADO por execução real do spike T1 (2026-09-28 17:39):** `Tokenizer()` devolve um
array de **posições numéricas** (`ValType == "N"`) — uma posição por match encontrado, **não**
uma posição/valor por grupo de captura. Testado contra o bloco `WSRESTFUL` do exemplo-alvo com
4 padrões diferentes (cabeçalho do serviço com 2 grupos, WSDATA com 3 grupos, verbo WSMETHOD
com 2 grupos × 2 ocorrências, PATH com 1 grupo × 2 ocorrências): em todos os casos, `itemCount`
bateu com o **número de matches** (1, 1, 2, 2), nunca com o número de grupos de captura — ou
seja, os grupos `(...)` no padrão **não são individualmente expostos** por `Tokenizer()`. Para
extrair o texto capturado, é necessário `SubStr()` manual a partir da posição devolvida (o
comprimento do match não vem junto — precisa ser descoberto por outro meio, ex.: um segundo
padrão mais estreito, ou o método `Matches()`, ver abaixo).

**CONFIRMADO — `Matches()` não serve para extrair texto capturado:** follow-up do spike
capturou o valor real devolvido por `Matches(cTexto)` (não só se lança exceção): `{"type":
"L", "value": false}` — um **Logical**, e `false`, mesmo com o mesmo padrão/texto onde
`Tokenizer()` já tinha confirmado `matched=true`. Isso indica que `Matches()` testa se a
**string inteira** bate com o padrão (semântica tipo "fullmatch", ancorada em `^...$`), não
se o padrão ocorre em algum trecho do texto — por isso `false` num texto maior que só contém
o match numa parte dele. **`Matches()` está descartado como via de extração.**

**Conclusão fechada do T1 (Ramo A) — algoritmo de extração para T2:** nem `Tokenizer()`
(só posições) nem `Matches()` (só fullmatch booleano) expõem o texto capturado pelos grupos
`(...)` de um padrão. O algoritmo real do `OApiWsrParser` (T2+) é um **híbrido**: usar
`Regex():Tokenizer()` para **localizar** (confirmar que a forma esperada existe e obter a
posição inicial do match — muito mais robusto que `At()` sozinho para distinguir, por
exemplo, a declaração real `WSRESTFUL HelloAdvpl DESCRIPTION "..."` de uma ocorrência
incidental da palavra `WSRESTFUL` dentro de um comentário de documentação — ver bug real
abaixo), e então usar `SubStr()`/`At()` (já confirmados) para **extrair** o valor a partir
dessa posição — análogo ao próprio uso real de produção (`TAFA633.tlpp`/`TAFA615.tlpp`, que
já faz exatamente isso: `Tokenizer()` para achar/validar, `SubStr()` para fatiar o texto).

**Bug real encontrado no spike (mesma categoria):** a delimitação grosseira do bloco
`WSRESTFUL...END WSRESTFUL` em `custom.openapi.advpl.spike.parse.tlpp` usa `At("WSRESTFUL ",
...)` ingênuo, que pegou a ocorrência da palavra dentro do comentário de documentação do
arquivo (`/*/{Protheus.doc} ... Demonstra um servico\nWSRESTFUL com WSDATA, ...`) em vez da
declaração real — o `blockSample` retornado inclui esse trecho de comentário. Não corrompeu
os testes de regex (os padrões exigem a forma completa `WSRESTFUL <nome> DESCRIPTION "..."`,
que só ocorre de verdade uma vez), mas confirma na prática por que Ramo A usa regex para
localizar em vez de `At()` simples: `custom.openapi.advpl.spike.read.tlpp` tinha o mesmo bug
(`Left(cLinha,9)=="WSRESTFUL"` batia na linha de prosa do comentário) e foi corrigido exigindo
`DESCRIPTION` na mesma linha — o parser real (T2) deve reproduzir essa mesma robustez via
`Regex()`, não reintroduzir checagens ingênuas de prefixo.

**Continuações `;` (linha física AdvPL):** ao contrário do Ramo B (que reunia continuações
linha a linha com `Right(cLine,1)==";"`), o Ramo A colapsa continuações com uma simples
substituição de texto antes de aplicar qualquer padrão: `StrTran(cText, ";" + Chr(13) +
Chr(10), " ")` (e variante só `Chr(10)`) — mais simples que reconstrução manual linha a
linha, testado no próprio spike T1.

**`MemoRead()`/`MLCount()`/`MemoLine()` não são descartados:** continuam válidos como
mecanismo de *leitura* de arquivo e de referência de linha aproximada para pendências (ver
"Invariantes e validação" abaixo) — só o *mecanismo de extração de tokens* muda de
At()/SubStr() manual (Ramo B) para `Regex()` (Ramo A).

**Ramo B:** descartado como mecanismo de extração de tokens; mantido apenas como referência
histórica da decisão anterior. Registro completo da correção em
`docs/experiments/openapi-advpl-adapter.md` (T6).

---

## Restrição de plataforma: RootPath (confirmada por execução real, 2026-09-28)

`User Function` exposta via `@Get`/`@Post` roda como **job HTTP** (`[HTTPJOB]
MAIN=HTTP_START` no `appserver.ini`) — "um programa sem interface remota". Nesse contexto,
`MemoRead()` (e funções de arquivo em geral) só enxergam caminhos **relativos ao `RootPath`**
do ambiente, sem letra de drive. Um caminho absoluto (`d:/pasta/arquivo.prw`) é interpretado
como "estação do SmartClient" — que não existe em job — e `MemoRead()` retorna `""`
**silenciosamente**, sem lançar exceção (comportamento documentado publicamente: TOTVS
Central de Atendimento, "As funções de manipulação de arquivo funcionam via schedule?"; blog
"Path Relativo X Absoluto").

**Confirmado empiricamente no spike T1:**
- `MemoRead("d:/PROJETOS/Protheus/protheus-openapi/.../hello-advpl.prw")` (caminho absoluto)
  → `""` (vazio, sem erro).
- Arquivo copiado para `D:\TOTVS12\Protheus12_2510\protheus_data\openapi-advpl-adapter\hello-advpl.prw`
  (dentro do `RootPath` do ambiente `P12_2510`) e lido via
  `MemoRead("/openapi-advpl-adapter/hello-advpl.prw")` (caminho relativo, sem letra de drive)
  → sucesso, `textLen` bateu exatamente com o tamanho do arquivo (2073 bytes).

**Consequência para a API pública do adaptador:** `cFilePath` em `OApiWsrParser::parse()` e
`OApiWsrBuild::build()` é documentado como **caminho relativo ao `RootPath`**, não um
caminho de disco arbitrário. Isso é uma limitação de plataforma (não contornável dentro do
escopo desta fase), análoga à necessidade de copiar `hello-advpl.prw` para dentro do
`RootPath` para o próprio spike funcionar — ver também `context.md`.

## Causa raiz real de MLCount()==0: line-ending do arquivo, não o parâmetro de largura (confirmada por execução real, 2026-09-28)

Primeira hipótese testada (`nLinLen=0` para MLCount/MemoLine) estava errada — nunca
confirmada por uso real, só por inspeção de assinatura. Corrigido para `MLCount(cText,
32000)` (largura grande o bastante para nunca forçar quebra), mas **o resultado continuou
`0`** mesmo após recompilar e confirmar que o binário novo estava rodando. Investigação nos
bytes brutos do arquivo revelou a causa real: `examples/openapi-advpl-adapter/hello-advpl.prw`
foi salvo com **`LF` puro (estilo Unix)** — zero ocorrências de `CR` (`Chr(13)`) no arquivo
inteiro. `MLCount()`/`MemoLine()` são funções legadas (Clipper/DOS) que só reconhecem
**`CRLF`** como quebra real de linha — com `LF` puro, `MLCount()` sempre devolve `0`,
**independente da largura passada** (confirmado: nem `0` nem `32000` mudaram o resultado,
porque a largura nunca foi o problema).

**Correção real:** normalizar o texto para `CRLF` antes de chamar `MLCount()`/`MemoLine()`:
`cText := StrTran(cText, Chr(13), "")` seguido de `cText := StrTran(cText, Chr(10), Chr(13) +
Chr(10))`. Confirmado em `custom.openapi.advpl.spike.read.tlpp`.

**Nota para o parser real (T2+):** `examples/openapi-advpl-adapter/hello-advpl.prw` (e,
plausivelmente, qualquer fonte `.prw`/`.prg` real do ambiente) pode ter `LF` puro ou `CRLF` —
não presumir um dos dois. Duas opções para T2: (a) sempre normalizar para `CRLF` antes de
usar `MLCount`/`MemoLine` (mesma correção do spike), ou (b) evitar `MLCount`/`MemoLine`
completamente e contar linhas para fins de "linha aproximada" em pendências via contagem
manual de `Chr(10)` com `At()`/`StrTran()` — mais simples e correto para qualquer
line-ending, já que o parser real (Ramo A) já opera sobre o texto inteiro via `Regex()`, sem
depender de iteração linha a linha.

---

## Invariantes e validação

- O adaptador nunca escreve um `OApiPath` cujo template não venha diretamente do `PATH` extraído (sem reescrita ou inferência adicional). Isso é análogo à garantia da Fase 3 de usar o `endpoint` da annotation como única fonte do path.
- PATH ausente ou vazio → pendência acumulada + operação omitida (não gera path inválido).
- Conflito de path+verbo → rejeitado pela validação do núcleo (`OApiDoc::addPath()`), sem supressão.
- Toda pendência carrega contexto: arquivo, serviço, linha aproximada (número ou trecho da linha).
- O núcleo `OApi*` não ganha conhecimento de `WSRESTFUL`, arquivos `.prw` ou parsing.

---

## Estratégia de testes

- **T1 (spike):** validado por compilação e execução reais no `P12_2510`, evidência registrada no diário técnico. Não usa PROBAT formal — é investigação.
- **T2 em diante:** RED/GREEN com PROBAT, fixture `OApiWsrTst`.
  - Testes do parser são sobre texto embutido (string literal no próprio teste), não sobre arquivo real — elimina dependência de caminho de arquivo no ambiente de teste.
  - Testes do build usam o exemplo-alvo `hello-advpl.prw` via path real no servidor.
- **Compilação + PROBAT** a cada tarefa concluída (lição da Fase 3).
- Contrato estático Python (`validate-sources.py`): verifica encoding CP-1252 sem BOM nos `.tlpp` e `.prw`.

---

## Limitações deliberadas

| Limitação | Registrada em |
|-----------|--------------|
| PATH ausente (forma mais antiga) não é suportado como caso principal; gera pendência | context.md D2, spec.md ADVP-16 |
| PATH relativo (fragmento) não é suportado como caso principal; gera pendência | context.md D2 |
| DESCRIPTION com constante simbólica (STR0001) usa valor `""` + pendência | spec.md ADVP-05/06 |
| Bloco de implementação WSMETHOD não é parseado (PATHPARAM/QUERYPARAM ignorados) | spec.md, fora do escopo |
| `RESPONSE EaiObj` e tipos não-primitivos não geram schema | spec.md, fora do escopo |
| Descoberta em diretórios (múltiplos arquivos) não está implementada | spec.md, fora do escopo |
| Reflection runtime de serviços WSRESTFUL não existe na plataforma | context.md §1 |

---

## Rastreabilidade do design

| Requisitos | Componente |
|-----------|-----------|
| ADVP-01 a ADVP-03 | spike (T1) — leitura de arquivo + regex |
| ADVP-04 a ADVP-08 | `OApiWsrParser::parse()` — bloco e continuações (T2) |
| ADVP-09 a ADVP-13 | `OApiWsrParser::parse()` — WSDATA (T2/T3) |
| ADVP-14 a ADVP-19 | `OApiWsrParser::parse()` — WSMETHOD (T3) |
| ADVP-20 a ADVP-22 | `OApiWsrPath::toParams()` — inferência path/query (T4) |
| ADVP-23 a ADVP-26 | `OApiWsrBuild::build()` — montagem OApiDoc (T5) |
| ADVP-27 | diário técnico + documentação comparativa (T6) |
