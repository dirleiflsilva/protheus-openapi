# Adaptador para endpoints AdvPL (WSRESTFUL) — spike de parsing via Regex

## Ambiente alvo

| Componente | Versão alvo |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer REST | `P12_2510` (`http://localhost:8084/rest`), serviço `TOTVS-AppServer12_2510_REST` |
| RootPath do ambiente | `D:\TOTVS12\Protheus12_2510\protheus_data` (de `appserver.ini`) |

## Contexto

A Fase 4 precisa ler e tokenizar código-fonte AdvPL clássico (`WSRESTFUL`/`WSMETHOD`) em texto, não via reflection (não existe equivalente de runtime para `WSRESTFUL` — ver `context.md`). A pesquisa pré-spike original (2026-09-26) concluiu erradamente que "regex não existe" no AdvPL/TLPP, porque só verificou `_binary_functions.prw`/`.tlpp` da IDE (funções soltas) — sem checar se existe como **classe**. Corrigido em 2026-09-28 após o usuário apontar a documentação TDN "Classe RegEx": um grep amplo nas fontes padrão (`P12.1.2510-202505\Master\Fontes`) confirmou a classe `Regex` (namespace `tlpp.regex`) em uso real de produção (`TAFA633.tlpp`, `TAFA615.tlpp`, `backoffice.pgc.utils.repository.tlpp`, `agd-repository.utils.tlpp`). Ver `.specs/features/openapi-advpl-adapter/design.md`, seção "Ramo A confirmado por evidência real", para a evidência completa.

Este spike (T1) tinha dois objetivos: (a) confirmar que a leitura de arquivo funciona a partir de um endpoint REST real, e (b) descobrir empiricamente o formato exato devolvido por `Tokenizer()` da classe `Regex` quando o padrão tem grupos de captura — informação que nenhuma fonte real inspecionada esclarecia por completo.

## Spike — sequência de evidências (2026-09-28)

### 1. `getQueryParam` não existe — API inventada sem confirmação

Primeira tentativa de `GET /api/v1/openapi/advpl/spike/read` retornou `THREAD ERROR`:

```
Cannot find method TLPP.REST.REST:GETQUERYPARAM on U_TLASPKRD
```

`oRest:getQueryParam("cFile")` nunca foi confirmado em nenhuma fonte antes de ser usado — violação da própria disciplina do projeto. API real, já usada em `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp:22,32` deste mesmo projeto: `oRest:GetQueryRequest()` devolve `Json`, acessado por `jQuery["cFile"]`. Corrigido nos dois spikes.

### 2. Caminho absoluto falha silenciosamente — restrição de RootPath em contexto de job

Com o bug 1 corrigido, `MemoRead("d:/PROJETOS/Protheus/protheus-openapi/.../hello-advpl.prw")` (caminho absoluto) devolveu `""` — sem erro, parecendo "arquivo não encontrado":

```
{"success":false,"error":"MemoRead retornou string vazia - arquivo nao encontrado ou vazio","filePath":"d:/PROJETOS/..."}
```

Causa: `User Function` exposta via `@Get` roda como **job HTTP** (`[HTTPJOB] MAIN=HTTP_START` no `appserver.ini`) — "um programa sem interface remota". Nesse contexto, funções de arquivo só enxergam caminhos **relativos ao `RootPath`** do ambiente; um caminho absoluto é interpretado como "estação do SmartClient", que não existe em job, e a resolução falha silenciosamente (comportamento documentado publicamente: TOTVS Central de Atendimento, "As funções de manipulação de arquivo funcionam via schedule?"; blog "Path Relativo X Absoluto").

Confirmado copiando o arquivo-alvo para dentro do `RootPath` (`D:\TOTVS12\Protheus12_2510\protheus_data\openapi-advpl-adapter\hello-advpl.prw`) e testando com caminho relativo:

```
GET /api/v1/openapi/advpl/spike/read?cFile=/openapi-advpl-adapter/hello-advpl.prw
→ {"success":true,...,"textLen":2073,...}
```

`textLen` bateu exatamente com o tamanho do arquivo. **Consequência para a API pública do adaptador:** `cFilePath` em `OApiWsrParser`/`OApiWsrBuild` é documentado como caminho relativo ao `RootPath`, não um caminho de disco arbitrário.

### 3. `invalid class REGEX` — falta `Using Namespace tlpp.regex`

`GET /api/v1/openapi/advpl/spike/parse` retornou `THREAD ERROR`:

```
invalid class REGEX on U_TLASPKPRS
```

A classe `Regex` existe (confirmado no passo de pesquisa), mas todo uso real de produção grepado inclui `Using Namespace tlpp.regex` antes de usá-la — diretiva que não foi copiada ao transcrever a API para o spike. Corrigido adicionando a diretiva imediatamente antes de `User Function TlaSpkPrs()` (mesmo padrão de posicionamento visto em `TAFA633.tlpp:596`, direto acima da função que usa a classe, sem precisar de um bloco `namespace` envolvente).

### 4. `MLCount()`/`MemoLine()` sempre devolvem 0 — abandonadas em favor de split manual

Após os bugs 1-3 corrigidos, `lineCount` continuava `0` mesmo com `textLen=2073` (texto não vazio). Duas tentativas de ajuste de parâmetro não resolveram:

```
MLCount(cText, 0, 4, .F.)      → 0
MLCount(cText, 32000)          → 0  (recompilado e testado, resultado identico)
```

Inspeção de bytes revelou a causa real: `hello-advpl.prw` foi salvo com `LF` puro (0 ocorrências de `Chr(13)` no arquivo inteiro). `MLCount()`/`MemoLine()` são funções legadas (Clipper/DOS) que só reconhecem `CRLF` como quebra real de linha — independente da largura passada. Normalizar o texto para `CRLF` (`StrTran` duplo) fez `textLen` crescer de `2073` para `2145` (+72 bytes = as 72 quebras `LF` viraram `CRLF`, confirmando que a normalização rodou), mas `MLCount()` **continuou devolvendo 0** mesmo com `CRLF` real presente — causa exata não identificada, e considerada fora de escopo.

Decisão: como o parser real (Ramo A) opera sobre o texto inteiro via `Regex()`, sem precisar iterar linha a linha, `MLCount()`/`MemoLine()` foram abandonadas em favor de um split manual por `Chr(10)` via `At()`/`SubStr()` (já confirmados funcionando) — resultado: `lineCount=72` correto, `firstLine` correto.

### 5. Falso positivo na detecção da linha `WSRESTFUL`

Com o split manual funcionando, `wsrestfulLineNum` apontou para a linha 6 — que é **prosa do comentário de documentação** do arquivo (`/*/{Protheus.doc} HelloAdvpl ... Demonstra um servico\nWSRESTFUL com WSDATA, dois metodos...`), não a declaração real. A checagem `Left(cLinha,9)=="WSRESTFUL"` bateu na palavra por coincidência de quebra de linha na prosa. Corrigido exigindo `DESCRIPTION` na mesma linha (`Left(cLineUp,9)=="WSRESTFUL" .And. At("DESCRIPTION",cLineUp)>0`):

```
GET /api/v1/openapi/advpl/spike/read?cFile=/openapi-advpl-adapter/hello-advpl.prw
→ {"success":true,...,"wsrestfulLineNum":12,
   "wsrestfulLine":"WSRESTFUL HelloAdvpl DESCRIPTION \"Hello World AdvPL com parametros\" FORMAT \"application/json\""}
```

O mesmo bug de falso positivo contamina a delimitação grosseira de bloco (`At("WSRESTFUL ", ...)`) em `custom.openapi.advpl.spike.parse.tlpp` — o `blockSample` retornado inclui o mesmo trecho de comentário. Não corrompeu os testes de regex (os padrões exigem a forma completa `WSRESTFUL <nome> DESCRIPTION "..."`, que só ocorre de verdade uma vez), mas confirma empiricamente por que o parser real (T2) deve usar `Regex()` para localizar em vez de `At()` ingênuo.

### 6. `Tokenizer()` devolve posições, não substrings capturadas

Objetivo central do spike. Testados 4 padrões contra o bloco `WSRESTFUL` real (cabeçalho do serviço com 2 grupos de captura, `WSDATA` com 3 grupos, verbo `WSMETHOD` com 2 grupos × 2 ocorrências, `PATH` com 1 grupo × 2 ocorrências):

```
GET /api/v1/openapi/advpl/spike/parse?cFile=/openapi-advpl-adapter/hello-advpl.prw
→ {"success":true,
   "testService":{"matched":true,"itemCount":1,"items":[{"index":1,"type":"N","value":194}]},
   "testWsData":{"matched":true,"itemCount":1,"items":[{"index":1,"type":"N","value":292}]},
   "testMethodVerb":{"matched":true,"itemCount":2,"items":[{"index":1,"type":"N","value":331},{"index":2,"type":"N","value":558}]},
   "testPath":{"matched":true,"itemCount":2,"items":[{"index":1,"type":"N","value":493},{"index":2,"type":"N","value":687}]}}
```

Em todos os casos, `itemCount` bateu com o **número de matches** encontrados (1, 1, 2, 2) — nunca com o número de grupos de captura do padrão — e todo item é `"type":"N"` (Numeric). **Confirmado: `Tokenizer()` devolve um array de posições de início de cada match, não os textos capturados pelos grupos `(...)`.**

### 7. `Matches()` existe, mas é um teste de fullmatch — não serve para extração

Follow-up testou o método especulativo `Matches()` com o mesmo padrão/texto do teste 6 (onde `Tokenizer()` já confirmou `matched=true`):

```
"testMatchesValue":{"called":true,"result":{"type":"L","value":false}}
```

`Matches()` existe (não lançou exceção) e devolve um `Logical` — mas `false`, mesmo com o padrão comprovadamente batendo numa parte do texto. Interpretação: `Matches()` testa se a **string inteira** bate com o padrão (semântica de fullmatch, ancorada), não se o padrão ocorre em algum trecho — por isso `false` num texto maior que só contém o match numa parte dele. **`Matches()` descartado como via de extração de texto capturado.**

## Conclusão

| Chamada | Assinatura confirmada | Retorno |
| --- | --- | --- |
| `Regex():New(cPattern)` / `New("")` + `SetPattern()` | reaproveitável no mesmo objeto (`TAFA615.tlpp:1726-1728`) | `Object` |
| `SetMultiline(lValor)` / `SetCaseSensitive(lValor)` | 1 argumento | sem retorno relevante |
| `Tokenizer(cTexto, , @aOut)` | 3 argumentos (2º posicional vazio nos usos reais vistos) | `Logical` (achou match); `aOut` = `Array` de **posições numéricas**, uma por match, não por grupo de captura |
| `Matches(cTexto)` | 1 argumento | `Logical` — fullmatch da string inteira, não busca parcial |
| `ReplaceAll(@cVar, cSubstituto)` | 2 argumentos | substituição in-place (confirmado só por uso de produção, não testado neste spike) |
| `oRest:GetQueryRequest()` | 0 argumentos | `Json`, indexado por nome do parâmetro |
| `MemoRead(cFile, lChangeCase)` | 2 argumentos | `Character`; caminho deve ser **relativo ao RootPath** em contexto de job (sem letra de drive) |
| `MLCount()`/`MemoLine()` | — | comportamento não confirmado nesta versão/ambiente (sempre devolveram 0 nos testes); **abandonadas**, substituídas por split manual via `At()`/`SubStr()` |

**Algoritmo de extração para `OApiWsrParser::parse()` (T2+):** nem `Tokenizer()` nem `Matches()` expõem o texto capturado pelos grupos `(...)`. O algoritmo real é um híbrido: `Regex():Tokenizer()` para **localizar** (confirma a forma esperada e obtém a posição inicial — muito mais robusto que `At()` sozinho para distinguir uma declaração real de uma ocorrência incidental de palavra-chave dentro de um comentário, como o bug 5 comprovou na prática), e então `SubStr()`/`At()` (já confirmados) para **extrair** o valor a partir dessa posição — o mesmo padrão já usado em produção (`TAFA633.tlpp`/`TAFA615.tlpp`: `Tokenizer()` para achar/validar, `SubStr()` para fatiar).

**Decisão:** Ramo A (design.md) confirmado como arquitetura definitiva do parser AdvPL. Ver `.specs/features/openapi-advpl-adapter/` para spec/design/tasks atualizados com a API real e o algoritmo de extração.
