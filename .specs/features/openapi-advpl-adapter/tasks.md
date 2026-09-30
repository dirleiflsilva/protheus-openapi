# Adaptador para endpoints AdvPL — Tarefas

**Design:** `.specs/features/openapi-advpl-adapter/design.md`  
**Spec:** `.specs/features/openapi-advpl-adapter/spec.md`  
**Estado:** T2 CONCLUIDO (2026-09-30) — `OApiWsrParser` real compilado e validado via PROBAT (fixture `OApiWsrTst`, 24 asserções) no `P12_2510`, sem `THREAD ERROR` nem `>> assert << - result: ERROR`. Proximo: T3 (extracao de `WSMETHOD`)

## Plano de execução

```text
T1 (spike) → T2 → T3 → T4 → T5 → T6
```

Compilação (`advpl-tlpp-compile`) e PROBAT executados a cada tarefa concluída a partir de T2 — lição aplicada da Fase 3.

Encoding: todo `.tlpp` gerado é salvo em UTF-8 e convertido para CP-1252 sem BOM antes de compilar (one-liner Python, ver `context.md` — nunca usar o `convert-encoding.bat` quebrado). Ao **editar** um `.prw`/`.tlpp` já em CP-1252 com acentos: reconverter para UTF-8 primeiro, editar, reconverter de volta para CP-1252.

---

## T1: Spike de leitura de arquivo e parsing em TL++ — CONCLUIDO

**O que:** confirmar com evidencia de compilacao e execucao reais no `P12_2510` que:
(a) `MemoRead()` le o conteudo de um arquivo `.prw` no AppServer pelo path absoluto;
(b) `MLCount()`/`MemoLine()` iteram corretamente as linhas do texto lido;
(c) a classe `Regex` (`SetPattern()`/`SetMultiline()`/`SetCaseSensitive()`/`Tokenizer()`) e
suficiente para tokenizar um bloco `WSRESTFUL` completo — e, especificamente, qual e o
formato real devolvido por `Tokenizer()` quando o padrao tem grupos de captura `(...)`.

**Ramo A adotado em 2026-09-28, corrigindo decisao de 2026-09-26:** a pesquisa original
("regex nao existe como binary function") so verificou `_binary_functions.prw`/`.tlpp` da
IDE — ou seja, so procurou regex como funcao solta. Regex no AdvPL/TLPP e uma **classe**
(`Regex`, namespace `tlpp.regex`), confirmada em uso real de producao nas fontes padrao
(`TAFA633.tlpp`, `TAFA615.tlpp`, `backoffice.pgc.utils.repository.tlpp`,
`agd-repository.utils.tlpp`). Ver `design.md`, secao "Ramo A confirmado por evidencia real
(correcao 2026-09-28)", para a evidencia completa e a API confirmada. O que **nao** esta
confirmado e o formato exato do array devolvido por `Tokenizer()` com grupos de captura —
esse e o objetivo central deste spike.

**Onde:** fontes criados/revisados em `examples/openapi-advpl-adapter/`:
- `hello-advpl.prw` — exemplo-alvo: servico `HelloAdvpl`, `WSDATA language AS STRING OPTIONAL`, dois metodos (GET + POST), PATH absoluto `/api/v1/hello-advpl` (sem alteracao pela troca de ramo)
- `custom.openapi.advpl.spike.read.tlpp` — endpoint `GET /api/v1/openapi/advpl/spike/read`: testa `MemoRead(cFile,.F.)`, faz split manual por `Chr(10)` (via `At()`/`SubStr()`) para contar/iterar linhas (MLCount/MemoLine abandonadas — ver bugs #2 abaixo), localiza a linha de declaracao `WSRESTFUL` (exigindo `DESCRIPTION` na mesma linha, para nao confundir com prosa de comentario — ver bug real abaixo), retorna amostra de 5 linhas
- `custom.openapi.advpl.spike.parse.tlpp` — endpoint `GET /api/v1/openapi/advpl/spike/parse`: usa `Regex():New()`/`SetPattern()`/`SetMultiline()`/`SetCaseSensitive()`/`Tokenizer()`; colapsa continuacoes `;` com `StrTran()`; testa 4 padroes (cabecalho do servico, WSDATA, verbo WSMETHOD, PATH) via `Static Function DumpTokenizer` que despeja tipo+valor bruto de cada elemento do array devolvido por `Tokenizer()`; testa tambem o valor real devolvido por `Matches()` via `Static Function DumpMatches`/`DumpValue` (nao so se lanca excecao)

**Depende de:** nenhuma.

**Reutiliza:** estrutura de spike da Fase 3 (`examples/openapi-tlpp-adapter/`).

**Requisitos:** ADVP-01 a ADVP-03.

**Skills:** `utf8-to-cp1252-conversion` (ja aplicada), `advpl-tlpp-compile`.

**Concluida quando:**

- [x] `hello-advpl.prw` criado em `examples/openapi-advpl-adapter/` com servico `HelloAdvpl`, `WSDATA language AS STRING OPTIONAL`, dois metodos GET/POST com PATH absoluto, implementacao minima.
- [x] `custom.openapi.advpl.spike.read.tlpp` criado — endpoint `GET /api/v1/openapi/advpl/spike/read`.
- [x] `custom.openapi.advpl.spike.parse.tlpp` revisado em 2026-09-28 para usar a classe `Regex` (Ramo A) — endpoint `GET /api/v1/openapi/advpl/spike/parse`.
- [x] Encoding CP-1252 sem BOM verificado nos tres fontes (zero bytes > 0x7F, sem BOM).
- [x] `hello-advpl.prw` compilou `[SUCCESS]` no `P12_2510` (2026-09-28 16:18).
- [x] `custom.openapi.advpl.spike.read.tlpp` compilou `[SUCCESS]` e testado com `lineCount=72` correto (2026-09-28 21:34) apos abandonar MLCount/MemoLine por split manual; 1 bug adicional encontrado no mesmo teste (falso positivo de deteccao da linha WSRESTFUL, ver abaixo) — correcao aplicada, recompilacao final pendente de confirmacao do usuario.
- [x] `custom.openapi.advpl.spike.parse.tlpp` compilou `[SUCCESS]` apos a correcao (getQueryParam) (2026-09-28 17:07).
- [x] **Bug de runtime #1 encontrado e corrigido (2026-09-28 16:24):** execucao real de `GET /api/v1/openapi/advpl/spike/read` retornou `THREAD ERROR` — `Cannot find method TLPP.REST.REST:GETQUERYPARAM on U_TLASPKRD`. O metodo `oRest:getQueryParam(nome)` nao existe; nunca foi confirmado nas fontes do projeto antes de usa-lo (violacao da propria regra de nao presumir API nao confirmada). API real, ja usada em `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp`: `oRest:GetQueryRequest()` devolve `Json`, acessado por `jQuery["cFile"]`. Corrigido em `custom.openapi.advpl.spike.read.tlpp` e `custom.openapi.advpl.spike.parse.tlpp` (ambos ja continham o mesmo erro).
- [x] **Restricao de plataforma descoberta (2026-09-28 16:52):** apos corrigir o bug #1, `MemoRead()` com caminho absoluto (`d:/PROJETOS/...`) retornou `""` (arquivo "nao encontrado"). Causa: `User Function` via `@Get` roda como job HTTP (sem interface remota) — nesse contexto, funcoes de arquivo so enxergam caminhos relativos ao `RootPath` do ambiente (`D:\TOTVS12\Protheus12_2510\protheus_data`, confirmado no `appserver.ini` do servico REST). Corrigido copiando `hello-advpl.prw` para `D:\TOTVS12\Protheus12_2510\protheus_data\openapi-advpl-adapter\hello-advpl.prw` e testando com caminho relativo (`/openapi-advpl-adapter/hello-advpl.prw`) — sucesso, `textLen=2073` bateu com o arquivo. Documentado em `context.md` e `design.md` ("Restricao de plataforma: RootPath") como implicacao permanente da API publica do adaptador (`cFilePath` e relativo ao RootPath, nao um caminho de disco arbitrario).
- [x] **Bug de runtime #2 encontrado e corrigido em 2 tentativas (2026-09-28 16:52-20:30):** com o caminho relativo certo, `success=true` e `textLen=2073`, mas `lineCount=0` (deveria ser > 0). Tentativa 1 (ERRADA, nao resolveu): trocar `nLinLen=0` por `32000` em `MLCount()`/`MemoLine()` — recompilado e testado, resultado identico (`lineCount=0`). Causa raiz real: `hello-advpl.prw` foi salvo com `LF` puro (0 ocorrencias de `Chr(13)` no arquivo inteiro, confirmado por inspecao de bytes) — `MLCount()`/`MemoLine()` sao funcoes legadas que so reconhecem `CRLF` como quebra real, independente da largura passada. Corrigido normalizando `cText` para `CRLF` antes de `MLCount`/`MemoLine` (`StrTran` duplo). Documentado em `design.md` ("Causa raiz real de MLCount()==0"). Compilacao do fonte corrigido ainda pendente.
- [x] Execucao de `GET /api/v1/openapi/advpl/spike/read?cFile=/openapi-advpl-adapter/hello-advpl.prw` retornou `success=true`, `lineCount=72`, `firstLine` correto, `wsrestfulLineNum=12` com `wsrestfulLine` sendo a declaracao real (2026-09-28 21:43, apos correcao do falso positivo).
  - Evidencia: `{"mlCountDiagnostic":29,"success":true,...,"lineCount":72,"firstLine":"#include \"totvs.ch\"","wsrestfulLineNum":12,"wsrestfulLine":"WSRESTFUL HelloAdvpl DESCRIPTION \"Hello World AdvPL com parametros\" FORMAT \"application/json\"",...}`.
- [x] **Bug real #4 encontrado e corrigido (2026-09-28 21:34):** `wsrestfulLineNum` apontou para a linha 6, que e **prosa do comentario de documentacao** ("WSRESTFUL com WSDATA, dois metodos...") que comeca com a palavra "WSRESTFUL" por coincidencia de quebra de linha, nao a declaracao real. Corrigido exigindo `DESCRIPTION` na mesma linha (`Left(cLineUp,9)=="WSRESTFUL" .And. At("DESCRIPTION",cLineUp)>0`) em `custom.openapi.advpl.spike.read.tlpp`. O mesmo tipo de falso positivo tambem contamina a delimitacao grosseira do bloco em `custom.openapi.advpl.spike.parse.tlpp` (`blockSample` inclui o mesmo trecho de comentario) — nao corrompeu os testes de regex la (os padroes exigem a forma completa, unica na declaracao real), mas confirma empiricamente por que o parser real (T2) deve usar `Regex()` para localizar, nao `At()` ingenuo. Documentado em `design.md`.
- [x] Execucao de `GET /api/v1/openapi/advpl/spike/parse?cFile=/openapi-advpl-adapter/hello-advpl.prw` retornou `success=true` e, em `testService`/`testWsData`/`testMethodVerb`/`testPath`, `matched=true` com `itemCount` correto (1, 1, 2, 2) — todos os `items` sao `"type":"N"` com valores numericos (posicoes), nunca substrings (2026-09-28 21:34).
  - Evidencia: `{"success":true,...,"testService":{"matched":true,"itemCount":1,"items":[{"index":1,"type":"N","value":194}]},"testMatchesValue":{"called":true,"result":{"type":"L","value":false}},"testWsData":{"matched":true,"itemCount":1,...},"testMethodVerb":{"matched":true,"itemCount":2,...},"testPath":{"matched":true,"itemCount":2,...}}`.
- [x] Decisao registrada (2026-09-28, definitiva): `Tokenizer()` devolve **posicoes numericas** (uma por match, nao por grupo de captura); `Matches()` devolve **Logical** (teste de fullmatch da string inteira, nao encontra ocorrencia parcial) — testado e confirmado `false` mesmo com match parcial real presente. Nenhum dos dois metodos expõe o texto capturado pelos grupos `(...)`. Algoritmo de `OApiWsrParser::parse()` (T2+): `Regex():Tokenizer()` para localizar + `SubStr()`/`At()` para extrair, a partir da posicao confirmada. Documentado em `design.md` ("Conclusao fechada do T1").
- [x] Ramo A documentado no diario tecnico `docs/experiments/openapi-advpl-adapter.md` com as evidencias brutas (incluindo a correcao em relacao ao Ramo B de 2026-09-26).
- [x] `design.md` atualizado com Ramo A como definitivo (2026-09-28, corrige decisao de 2026-09-26).
- [x] **Bug de runtime #3 encontrado e corrigido (2026-09-28 17:27):** execucao de `GET /api/v1/openapi/advpl/spike/parse` retornou `THREAD ERROR` — `invalid class REGEX`. Causa: `custom.openapi.advpl.spike.parse.tlpp` chamava `Regex():New(...)` sem declarar `Using Namespace tlpp.regex` — a API confirmada nas fontes padrao (design.md) sempre inclui essa diretiva antes do uso da classe, mas ela nao foi copiada ao transcrever a API para o spike. Corrigido adicionando `Using Namespace tlpp.regex` imediatamente antes de `User Function TlaSpkPrs()` (mesmo padrao de posicionamento visto em `TAFA633.tlpp:596`, diretamente antes da funcao que usa a classe). Compilacao do fonte corrigido ainda pendente.

**Commit:** `test(openapi): spike de leitura de arquivo e parsing para adaptador AdvPL`

---

## T2: Parser do bloco WSRESTFUL — reconhecimento e WSDATA — CONCLUIDO

**O quê:** classe `OApiWsrParser` (`Method parse(cFilePath) as Array`) que:
1. Lê o arquivo com `MemoRead()`.
2. Reúne continuações `;` (linhas físicas → linhas lógicas).
3. Identifica o início e fim do bloco `WSRESTFUL … END WSRESTFUL` / `ENDWSRESTFUL`.
4. Extrai nome do serviço e DESCRIPTION (literal ou constante → pendência).
5. Extrai cada `WSDATA` com nome, tipo e flag `OPTIONAL`.

Nesta tarefa, `methods` é retornado como array vazio — o parsing de `WSMETHOD` dentro do bloco fica para T3.

**Onde:** `src/adapters/custom.openapi.adapter.advpl.parser.tlpp`; teste em `tests/openapi-advpl-adapter/custom.openapi.advpl.adapter.test.tlpp` (fixture `OApiWsrTst`); contrato estático em `tests/openapi-advpl-adapter/validate-sources.py`.

**Depende de:** T1 (Ramo A ou B do parser confirmado).

**Reutiliza:** `MemoRead()` + mecanismo de parsing confirmado no spike; nenhuma classe `OApi*` do núcleo é chamada nesta tarefa.

**Requisitos:** ADVP-04 a ADVP-13.

**Skills:** `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] `parse("/openapi-advpl-adapter/hello-advpl.prw")` retorna um array com um `Json` contendo `service = "HelloAdvpl"`, `desc = "Hello World AdvPL com parametros"`, `wsdata` com um item `{name:"language", type:"string", optional:.T.}`, `methods = {}`, `pending = {}` (validado via PROBAT — caminho relativo ao RootPath, ver "Restrição de plataforma: RootPath" em design.md).
- [x] Arquivo sem nenhum bloco `WSRESTFUL` retorna array vazio sem falhar.
- [x] `DESCRIPTION` com constante simbólica (arquivo de teste embutido gravado via `MemoWrite()`, já que `parse()` só aceita caminho de arquivo) retorna `desc = ""` e uma pendência com o nome da constante.
- [x] `WSDATA x AS ARRAY` retorna `type = "string"` e uma pendência de tipo não suportado.
- [x] Continuação `;` em `WSRESTFUL ... DESCRIPTION ...;` é reunida corretamente antes da extração (comparado byte-a-byte contra a versão equivalente em uma linha só).
- [x] Testes PROBAT: 24 asserções (acima do mínimo de 8) no fixture `OApiWsrTst`; execução real no `P12_2510` em 2026-09-30 sem `THREAD ERROR` nem `>> assert << - result: ERROR` (thread finalizou limpo).
- [x] Compilação `[SUCCESS]` nos 2 fontes novos (`custom.openapi.adapter.advpl.parser.tlpp`, `custom.openapi.advpl.adapter.test.tlpp`) confirmada pelo usuário em 2026-09-30. Encoding CP-1252 sem BOM verificado (contrato estático `tests/openapi-advpl-adapter/validate-sources.py` passou).
- [x] Conflito descoberto e corrigido: `tests/openapi-tlpp-adapter/validate-sources.py` proibia `MemoRead`/`MemoWrite` via glob `src/adapters/*.tlpp` — pegaria também o novo `OApiWsrParser`, que precisa dessas chamadas (o oposto da premissa do adaptador TL++). Corrigido para lista explícita dos 4 fontes do adaptador TL++, sem afetar o adaptador AdvPL.

**Commit:** `feat(openapi): OApiWsrParser extrai servico e WSDATA do bloco WSRESTFUL`

---

## T3: Parser do bloco WSRESTFUL — operações WSMETHOD

**O quê:** estender `OApiWsrParser::parse()` para extrair cada `WSMETHOD` dentro do bloco de definição: verbo, nome de ação opcional, DESCRIPTION e PATH (cláusulas que podem estar na mesma linha lógica ou em linhas lógicas separadas dentro do bloco).

**Onde:** `src/adapters/custom.openapi.adapter.advpl.parser.tlpp` (estendido); testes e contrato estendidos nos mesmos arquivos de T2.

**Depende de:** T2.

**Requisitos:** ADVP-14 a ADVP-19.

**Skills:** `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `parse("examples/openapi-advpl-adapter/hello-advpl.prw")` retorna `methods` com dois itens: `{verb:"GET", action:"Hello", desc:"...", path:"/api/v1/hello-advpl", wssyntax:"/api/v1/hello-advpl?{language}"}` e `{verb:"POST", action:"Hello", desc:"...", path:"/api/v1/hello-advpl", wssyntax:"/api/v1/hello-advpl"}`.
- [ ] WSMETHOD com `PATH` ausente produz `path = ""` e uma pendência.
- [ ] WSMETHOD com `PATH ""` (string vazia explícita) produz `path = ""` e uma pendência.
- [ ] WSMETHOD com DESCRIPTION como constante simbólica produz `desc = ""` e uma pendência.
- [ ] WSMETHOD multilinha (cláusulas separadas por `;`) é reunido corretamente e extrai os mesmos campos da versão de linha única.
- [ ] Testes PROBAT: mínimo 14 asserções no total (acumula com T2); sem `THREAD ERROR`.
- [ ] Compilação `[SUCCESS]`. Encoding CP-1252 sem BOM verificado.

**Commit:** `feat(openapi): OApiWsrParser extrai operacoes WSMETHOD do bloco de definicao`

---

## T4: Inferência de localização de parâmetros — `OApiWsrPath`

**O quê:** classe `OApiWsrPath` (`Method toParams(cPath, aWsData) as Array`) que recebe o PATH de uma operação e a lista de WSDATA do serviço, e retorna um array de `OApiParam` com `in: path`/`in: query` inferido pela presença ou ausência do nome em `{...}` no PATH. Mapeamento de tipo WSDATA → schema OpenAPI incluído.

**Onde:** `src/adapters/custom.openapi.adapter.advpl.path.tlpp`; testes e contrato estendidos nos mesmos arquivos de T2/T3.

**Depende de:** T3.

**Reutiliza:** `OApiParam` e `OApiSchema` do núcleo (sem modificação).

**Requisitos:** ADVP-20 a ADVP-22.

**Skills:** `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `toParams("/v1/hello-advpl", [{name:"language", type:"string", optional:.T.}])` retorna um `OApiParam` com `in: "query"`, `required: false`, schema `{type:"string"}`.
- [ ] `toParams("/v1/hello/{code}", [{name:"code", type:"string", optional:.F.}, {name:"page", type:"integer", optional:.T.}])` retorna dois `OApiParam`: `{in:"path", required:true, name:"code"}` e `{in:"query", required:false, name:"page"}`.
- [ ] PATH vazio `""` com WSDATA qualquer retorna array de parâmetros com `in: "query"` para todos (sem path params possíveis).
- [ ] Tipo `BOOLEAN` → schema `{type:"boolean"}`.
- [ ] Tipo `ARRAY` → schema `{type:"string"}` + pendência.
- [ ] Testes PROBAT: mínimo 20 asserções no total; sem `THREAD ERROR`.
- [ ] Compilação `[SUCCESS]`. Encoding CP-1252 sem BOM verificado.

**Commit:** `feat(openapi): OApiWsrPath infere localizacao de parametros WSDATA no path`

---

## T5: Montar o OApiDoc — `OApiWsrBuild`

**O quê:** classe `OApiWsrBuild` (`Method build(oDoc, cFilePath) as Logical`) que orquestra parser + path e monta `OApiPath`/`OApiOper`/`OApiParam` no `OApiDoc` fornecido, agrupando operações por template de path antes de chamar `OApiDoc::addPath()` (mesmo padrão da Fase 3).

**Onde:** `src/adapters/custom.openapi.adapter.advpl.build.tlpp`; testes e contrato estendidos nos mesmos arquivos de T2-T4.

**Depende de:** T4.

**Reutiliza:** `OApiPath`, `OApiOper`, `OApiDoc` do núcleo; `OApiWsrParser` e `OApiWsrPath` desta fase.

**Requisitos:** ADVP-23 a ADVP-26.

**Skills:** `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `build(oDoc, "examples/openapi-advpl-adapter/hello-advpl.prw")` retorna `.T.` e o `oDoc` resultante contém um `OApiPath "/api/v1/hello-advpl"` com operações GET e POST, cada uma com o `OApiParam language` (in: query, required: false, type: string).
- [ ] `oDoc:validate()` retorna zero pendências para esse cenário.
- [ ] Chamar `build()` duas vezes com o mesmo arquivo e mesmo `oDoc` causa rejeição pelo núcleo (`OApiDoc::addPath()` rejeita path+verbo duplicado) — a `UserException` é capturada e registrada como pendência, sem travar a execução.
- [ ] Arquivo sem nenhum bloco WSRESTFUL retorna `.F.` e zero paths adicionados, sem exceção.
- [ ] Testes PROBAT: mínimo 26 asserções no total; sem `THREAD ERROR`.
- [ ] Compilação `[SUCCESS]` nos 3 fontes do adaptador. Encoding CP-1252 sem BOM verificado.

**Commit:** `feat(openapi): OApiWsrBuild monta OApiDoc a partir de WSRESTFUL AdvPL`

---

## T6: Documentar evidências, limitações e comparação — diário técnico

**O quê:** registrar no diário técnico do incremento (`docs/experiments/openapi-advpl-adapter.md`) as evidências do spike, a rastreabilidade completa ADVP-01 a ADVP-27, as limitações deliberadas e a comparação objetiva com o adaptador TL++ (ADVP-27). Atualizar o README (Fase 4 de "Planejado" para "Implementado e validado").

**Onde:** `docs/experiments/openapi-advpl-adapter.md` (novo); `README.md` (atualizado).

**Depende de:** T5.

**Requisitos:** ADVP-27, rastreabilidade de ADVP-01 a ADVP-27.

**Concluída quando:**

- [ ] Diário técnico criado com: spike (resultado, Ramo A ou B), rastreabilidade ADVP-01 a ADVP-27 (evidências de compilação + PROBAT por tarefa), comparação TL++ × AdvPL (tabela), limitações deliberadas.
- [ ] README atualizado: Fase 4 marcada como "Implementado e validado (compilação e PROBAT reais)", nova seção descrevendo as 3 classes do adaptador e a diferença arquitetural em relação à Fase 3.
- [ ] Rastreabilidade completa: 27/27 requisitos com evidência registrada.

**Commit:** `docs(openapi): registra adaptador AdvPL validado e atualiza roadmap`

---

## Validações pré-aprovação

- **Granularidade:** T1 é investigação isolada; T2/T3 dividem o parser em dois incrementos para manter cada tarefa verificável; T4/T5 são conversão e montagem, uma por tarefa.
- **Dependências:** cadeia linear — T1 → T2 → T3 → T4 → T5 → T6. Sem bifurcação após T1 (Ramo A/B é transparente para T2 em diante).
- **Testes co-localizados:** a partir de T2, cada tarefa evolui o mesmo conjunto de testes e roda compilação + PROBAT antes de ser considerada concluída.
- **Cobertura:** ADVP-01 a ADVP-27 estão associados a pelo menos uma tarefa.
- **Encoding:** cada tarefa que gera `.tlpp` inclui conversão UTF-8 → CP-1252 e verificação de ausência de U+FFFD como critério de conclusão.
