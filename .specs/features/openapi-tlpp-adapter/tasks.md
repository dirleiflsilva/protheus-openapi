# Adaptador para endpoints TL++ - Tarefas

**Design:** `.specs/features/openapi-tlpp-adapter/design.md`
**Estado:** T1 a T6 concluídas com evidência real (2026-09-25) — spike, descoberta, path, metadados, montagem final e documentação. Ver `docs/experiments/openapi-tlpp-adapter.md` para a rastreabilidade completa.

## Plano de execução

```text
T1 (spike) -> T2 -> T3 -> T4 -> T5 -> T6   [todas concluídas em 2026-09-25]
```

Compilação (`advpl-tlpp-compile`) e PROBAT rodam a cada tarefa concluída a partir de T2, não só ao final — lição aplicada da sessão anterior, em que T1-T9 da feature anterior só foram compiladas/verificadas numa sessão separada.

## T1: Spike de verificação da API de reflection — CONCLUÍDA (2026-09-25)

**O quê:** confirmar ou refutar, com evidência real de compilação e execução no `P12_2510`, a existência de uma API de reflection capaz de localizar `User Function` anotadas com `@Get`/`@Post`/etc. e ler os atributos textuais da annotation (`endpoint`, `title`, `description`, `responses`).
**Onde:** 7 fontes de spike isolados em `examples/openapi-tlpp-adapter/custom.openapi.tlpp.spike.*.tlpp` (control, enum, attr2, attr3, inspect, inspect2, inspect3).
**Depende de:** nenhuma.
**Reutiliza:** os dois exemplos-alvo já anotados e validados via HTTP real (`custom.openapi.hello.get.tlpp`, `custom.openapi.hello.post.tlpp`) como alvo da introspecção.
**Requisitos:** ADPT-01 a ADPT-03.
**Skills:** `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] pelo menos uma tentativa de sintaxe para acessar a API de reflection candidata foi escrita e compilada contra o `P12_2510`, com o resultado literal (sucesso ou erro de compilação) registrado — todos os 7 fontes compilaram `[SUCCESS]`;
- [x] a API foi executada via HTTP real sobre os dois exemplos-alvo, e a estrutura real de retorno (campos, tipos, valores) foi capturada e registrada — ver `docs/experiments/openapi-tlpp-adapter.md`;
- [x] resultado (sucesso, com a assinatura real de cada chamada) registrado explicitamente, incluindo os palpites que estavam errados (aridade 2 vs. 3 argumentos) e o motivo;
- [x] o Ramo A (`design.md`) foi confirmado com base no resultado real; Ramo B rebaixado a fallback documentado;
- [x] resultado documentado no diário técnico do incremento (`docs/experiments/openapi-tlpp-adapter.md`).

**Commit:** `test(openapi): verifica mecanismo real de reflection TLPP`

---

## T2: Implementar a função de descoberta de funções anotadas — CONCLUÍDA (2026-09-25)

**O quê:** classe `OApiAdpDsc` (`Method discover(cVerb, aSources)`) que chama `Reflection.getFunctionsByAnnotation(cVerbo)`, filtra pelo `cSourceName`, e para cada par filtrado chama `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cVerbo)`, devolvendo os metadados brutos (`endpoint`/`title`/`description`/`responses`/`params`/`requestBody`) para os dois exemplos-alvo.
**Onde:** `src/adapters/custom.openapi.adapter.discovery.tlpp` (namespace `custom.openapi.adapter.tlpp`); teste em `tests/openapi-tlpp-adapter/custom.openapi.tlpp.adapter.test.tlpp` (fixture `OApiAdpTst`); contrato estático em `tests/openapi-tlpp-adapter/validate-sources.py`.
**Depende de:** T1.
**Reutiliza:** `Reflection.*` confirmado; nenhuma classe `OApi*` é chamada ainda nesta tarefa.
**Requisitos:** ADPT-04 a ADPT-06, ADPT-09.

**Concluída quando:**

- [x] a função de descoberta localiza exatamente `HeloGet`/`Get` e `HeloPost`/`Post` entre os 297+ resultados do RPO, ignorando o restante;
- [x] uma função sem a annotation de verbo é simplesmente ignorada, sem interromper a descoberta das demais (`discover("Delete", aAlvos)` devolve vazio);
- [x] `title`/`description` ausentes não quebram a função (comportamento herdado do próprio `Reflection.getFunctionAnnotation`, que já devolve `""` como default);
- [x] testes (PROBAT — fixture `OApiAdpTst`, 4 asserções, sem `THREAD ERROR`), encoding (CP1252 sem BOM) e compilação (`[SUCCESS]` nos 2 fontes) passam.

**Commit:** `feat(openapi): descobre funcoes TL++ anotadas via reflection`

## T3: Parser de path e parâmetros de path — CONCLUÍDA (2026-09-25)

**O quê:** classe `OApiAdpPath` (`toTemplate(cEndpoint)`, `toParams(cEndpoint)`) que converte o texto de `endpoint` (`:nome` → `{nome}`) e gera um `OApiParam` de path obrigatório (schema `string`) para cada segmento, na ordem em que aparecem — chamando a API já existente do núcleo (`OApiSchema`, `OApiParam`).
**Onde:** `src/adapters/custom.openapi.adapter.path.tlpp`; testes e contrato estendidos nos mesmos arquivos de T2.
**Depende de:** T2.
**Requisitos:** ADPT-07, ADPT-10.

**Concluída quando:**

- [x] `/api/v1/hello/:name` (endpoint real descoberto por `OApiAdpDsc`, nunca redigitado) vira `/api/v1/hello/{name}` e gera um `OApiParam` de path `name` obrigatório com schema `string`;
- [x] `/api/v1/hello` (sem segmento de path) permanece inalterado e não gera nenhum `OApiParam`;
- [x] o path resultante nunca diverge do texto do `endpoint` (impossibilita por construção a classe de bug da sessão anterior — o teste usa o endpoint *descoberto*, não um literal redigitado no teste);
- [x] testes (PROBAT — 10 asserções no total, sem `THREAD ERROR`), encoding (CP1252 sem BOM) e compilação (`[SUCCESS]`) passam.

**Commit:** `feat(openapi): converte endpoint anotado em template e parametros de path`

## T4: Definir e ler `params`/`requestBody` — CONCLUÍDA (2026-09-25)

**O quê:** classe `OApiAdpMeta` (`toQueryParams(cParamsJson)`, `toBody(cBodyJson)`) que converte os atributos `params`/`requestBody` (strings JSON) em `OApiParam` de query e `OApiBody`. Formato definido: `params='{"items":[{"name","in","required","type","description"}]}'` (embrulhado em objeto — `FromJson()` só está confirmado para JSON top-level objeto neste projeto, nunca testado com array solto); `requestBody='{"required","description","ref"}'` onde `ref` nomeia um schema já registrado no `OApiDoc` alvo.
**Onde:** `src/adapters/custom.openapi.adapter.metadata.tlpp`; os dois exemplos-alvo atualizados (`examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp` ganhou `params` com `language`; `custom.openapi.hello.post.tlpp` ganhou `requestBody` referenciando `HelloRequest`); testes e contrato estendidos nos mesmos arquivos de T2/T3.
**Depende de:** T3.
**Requisitos:** ADPT-11, ADPT-12.

**Concluída quando:**

- [x] formato de `params`/`requestBody` documentado (JSON serializado compatível com `OApiParam`/`OApiBody`, ver `design.md`);
- [x] `language` (query opcional, real, descoberto de `HeloGet`) e o body `HelloRequest` do POST (real, descoberto de `HeloPost`) são extraídos corretamente;
- [x] ausência de `params`/`requestBody` (string vazia) não quebra a operação — devolve array vazio / `Nil`, sem exceção;
- [x] testes (PROBAT — 16 asserções no total, sem `THREAD ERROR`), encoding (CP1252 sem BOM) e compilação (`[SUCCESS]` nos 4 fontes) passam.

**Commit:** `feat(openapi): converte params e requestBody da annotation em OApiParam e OApiBody`

## T5: Montar e comparar com o documento manual — CONCLUÍDA (2026-09-25)

**O quê:** classe `OApiAdpBuild::build(oDoc, aVerbs, aSources)` que descobre, converte e monta os `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody`/`OApiResp` completos para os verbos e fontes informados, agrupando operações por template de path antes de registrar cada path uma única vez em `oDoc` (necessário porque `OApiDoc::addPath()` rejeita path repetido mesmo com operações diferentes). `OApiAdpMeta` ganhou `toResponses()`; o atributo `responses` dos dois exemplos-alvo foi reformatado para o mesmo padrão embrulhado em objeto (`{"items":[...]}`) usado por `params`, incluindo `ref` opcional por resposta.
**Onde:** `src/adapters/custom.openapi.adapter.build.tlpp`; `OApiAdpMeta::toResponses()` em `custom.openapi.adapter.metadata.tlpp`; os dois exemplos-alvo tiveram `responses` reformatado; testes e contrato estendidos nos mesmos arquivos de T2-T4.
**Depende de:** T4.
**Requisitos:** ADPT-08, ADPT-13, ADPT-14.

**Concluída quando:**

- [x] o `OApiDoc` gerado automaticamente é estruturalmente equivalente ao montado manualmente para as duas operações (2 paths, GET com 2 parâmetros e resposta 200→`HelloResponse`, POST com body→`HelloRequest` e respostas 200→`HelloResponse`/400→`ErrorResponse`), e `oFullDoc:validate()` devolve zero pendências;
- [x] path+verbo duplicado é rejeitado pela validação já existente do núcleo (`OApiDoc::addPath()`), sem sobrescrever silenciosamente — comprovado chamando `build()` uma segunda vez com os mesmos alvos e capturando a `UserException`;
- [x] annotation malformada continua virando pendência acumulada (herdado de T2/T4 — nenhuma mudança necessária aqui);
- [x] testes (PROBAT — cerca de 31 asserções no total, sem `THREAD ERROR`), encoding (CP1252 sem BOM) e compilação (`[SUCCESS]` nos 5 fontes) passam.

**Commit:** `feat(openapi): monta o OApiDoc completo a partir da introspeccao TL++`

## T6: Registrar evidências, limitações e atualizar o roadmap — CONCLUÍDA (2026-09-25)

**O quê:** documentar o que foi e não foi automatizado, as limitações de inferência (ADPT-15), a rastreabilidade completa e atualizar o estado da Fase 3 no README.
**Depende de:** T5.
**Requisitos:** ADPT-15, rastreabilidade de ADPT-01 a ADPT-15.

**Concluída quando:**

- [x] limitações documentadas (reflection em métodos de classe, tipos de retorno, parâmetros formais, rotas dinâmicas via `sLoadURNs`, descoberta de schemas, escala) — ver `docs/experiments/openapi-tlpp-adapter.md`;
- [x] README atualizado (Fase 3: de "Planejado" para "Implementado e validado (compilação e PROBAT reais)", com nova seção descrevendo as 4 classes do adaptador);
- [x] rastreabilidade completa ADPT-01 a ADPT-15 no diário técnico — 15/15 requisitos com evidência registrada.

**Commit:** `docs(openapi): registra adaptador TL++ validado e atualiza roadmap`

## Validações pré-aprovação

- **Granularidade:** T1 foi isolada de propósito (investigação, não entrega) e já está concluída; T2 em diante entregam uma função/capacidade cada.
- **Dependências:** o plano é linear — cada tarefa depende diretamente da anterior, sem bifurcação (Ramo A já está confirmado).
- **Testes co-localizados:** a partir de T2, cada tarefa evolui o mesmo conjunto de testes do adaptador e roda compilação + PROBAT antes de ser considerada concluída.
- **Cobertura:** ADPT-01 a ADPT-15 estão associados a pelo menos uma tarefa.
