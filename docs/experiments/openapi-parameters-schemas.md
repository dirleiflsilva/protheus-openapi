# Parâmetros e schemas do modelo OpenAPI

## Ambiente alvo

| Componente | Versão alvo |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 (build 7.00.240223P) |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 |

Esta tabela repete o ambiente registrado em [docs/experiments/openapi-core-model.md](openapi-core-model.md) porque este incremento estende o mesmo núcleo. A implementação original (T1–T9, commits de 2026-09-10) foi escrita sem compilar nem rodar o PROBAT — o usuário optou por não compilar a cada tarefa. **Em 2026-09-24, todos os 11 fontes da feature foram compilados no `P12_2510` e o fixture `OApiTst` rodou via `tlpp.probat.run` com sucesso (0 erros), seguido de verificação HTTP real dos endpoints de demonstração.** Ver "Sessão de validação em runtime (2026-09-24)" abaixo.

## Sessão de validação em runtime (2026-09-24)

Esta seção fecha a lacuna registrada em "Evolução TDD" e na tabela de rastreabilidade: compilação real e execução do PROBAT, adiadas desde a implementação original.

1. **Compilação.** Os 11 fontes da feature (9 em `src/core/`, `tests/openapi-core/custom.openapi.core.test.tlpp`, `examples/openapi-core/custom.openapi.core.api.tlpp`, e os dois endpoints em `examples/openapi-parameters-schemas/`) foram compilados via `advpl-tlpp-compile` (tds-vscode) contra o servidor `P12_2510`, em dois lotes — todos com `[SUCCESS]`.
2. **PROBAT.** `tlpp.probat.run` executou o fixture `OApiTst` até o fim sem `THREAD ERROR`, cobrindo as 145 asserções de T1 a T9 (o log de sucesso não emite um resumo `ok:`/`err:` explícito no console — apenas a ausência de `THREAD ERROR` — diferente das rodadas com falha, que sempre emitiram `>> assert << - result: ERROR | ok: N err: 1`). Duas iterações intermediárias pegaram fontes não compilados (`OApiSchema`, depois `OApiParam`) antes do lote completo.
3. **HTTP real**, autenticado com o usuário `Admin` contra `http://localhost:8084/rest`:
   - `GET /api/v1/hello/mundo?language=pt-br` → `200`, `{"message":"Hello mundo","language":"pt-br","status":"success"}`
   - `POST /api/v1/hello {"name":"mundo"}` → `200`, `{"message":"Hello mundo","language":"TL++","status":"success"}` (default de `language` aplicado)
   - `POST /api/v1/hello {}` → `400`, `{"message":"Payload inválido.","status":"error"}` (sem detalhes internos)
   - `GET /api/v1/hello/mundo` sem credenciais → `401`
   - `GET /api/v1/openapi/core` → `200`, documento com as duas operações e os três schemas reutilizáveis
4. **Bug encontrado e corrigido durante a verificação HTTP:** o `GET` documentado em `GET /api/v1/openapi/core` declarava o parâmetro `name` como `"in":"path"`, mas estava registrado sob a chave de path `/api/v1/hello` — sem o placeholder `{name}` — porque `custom.openapi.core.api.tlpp` reaproveitava o mesmo `OApiPath("/api/v1/hello")` tanto para o `GET` (rota real `/api/v1/hello/:name`) quanto para o `POST` (rota real `/api/v1/hello`). Corrigido criando dois `OApiPath` distintos — `/api/v1/hello/{name}` para o `GET`, `/api/v1/hello` para o `POST` — e reverificado via nova chamada HTTP real ao endpoint recompilado. O endpoint REST em si (`custom.openapi.hello.get.tlpp`) sempre esteve correto; o bug era só na montagem manual da autodocumentação.
5. **Efeito colateral do bug:** a fixture estática `tests/openapi-core/fixtures/hello-params.json` continha exatamente o mesmo padrão inconsistente (herdado de quando foi escrita à mão, T7). Corrigida para o mesmo formato de dois paths. Isso quebrou `scripts/validate-hello-openapi.ps1`, que assumia que o `GET` do "path hello" estaria sempre numa chave terminada literalmente em `/api/v1/hello` — o script nunca soube lidar com path templates (`{param}`), porque foi escrito antes de esta feature introduzir parâmetros de path. Generalizado para aceitar `.../hello` ou `.../hello/{param}` e localizar dinamicamente qual dos dois candidatos tem a operação `GET`, mantendo as mesmas checagens de conteúdo (`summary`/`description`/`responses.200.description`). Ambas as fixtures (`hello-core.json`, `hello-params.json`) revalidadas com sucesso após a mudança, junto com o restante da bateria de gates.

## Objetivo e resultado

O incremento estende o núcleo mínimo (`openapi-core-model`) com parâmetros `path`/`query`/`header`, schemas primitivos/objeto/array/`$ref`, request body, respostas com schema e `components/schemas` com resolução transitiva de referências. Três classes novas (`OApiSchema`, `OApiParam`, `OApiBody`) se somam às seis existentes; `OApiOper`, `OApiResp`, `OApiDoc` e `OApiJson` foram estendidas.

```text
OApiSchema ──> components/schemas
     ↑                    ↑
OApiParam ──> OApiOper ──> OApiPath ──> OApiDoc ──> OApiJson
OApiBody  ──────┘             ↑
OApiResp  ────────────────────┘
```

| Classe | Responsabilidade nova nesta feature |
| --- | --- |
| `OApiSchema` | representar primitivo, objeto, array ou `$ref`; validar forma e propagar pendências aninhadas. |
| `OApiParam` | representar nome, localização, obrigatoriedade, schema e descrição de um parâmetro. |
| `OApiBody` | representar obrigatoriedade, schema e descrição do request body. |
| `OApiOper` | manter parâmetros únicos (por `in`+nome) e um request body opcional, preservando ordem. |
| `OApiResp` | aceitar um schema opcional para o conteúdo JSON. |
| `OApiDoc` | registrar componentes reutilizáveis e resolver referências `$ref` transitivamente. |
| `OApiJson` | serializar parâmetros, request body, respostas com schema e `components/schemas`. |

O incremento é demonstrado por `GET /api/v1/hello/:name` (parâmetro de path e query opcional), `POST /api/v1/hello` (request body validado) e pelo enriquecimento de `GET /api/v1/openapi/core`, que agora publica as duas operações e os três schemas reutilizáveis (`HelloRequest`, `HelloResponse`, `ErrorResponse`).

## Evolução TDD

Todas as tarefas seguiram RED (teste escrito antes da implementação) → GREEN (implementação mínima) → conversão CP-1252 → contrato estático → regressões → commit. Na sessão original (2026-09-10), "GREEN" significava que a implementação foi escrita para satisfazer as asserções, sem execução real no RPO. Em 2026-09-24 essa lacuna foi fechada: o fixture completo rodou via PROBAT sem erros (ver "Sessão de validação em runtime" acima).

| Tarefa | Entrega | Commit |
| --- | --- | --- |
| T1 | `OApiSchema` (discriminante, mutadores exclusivos, validação recursiva) | `71137c2`, 2026-09-10 11:19:48 — `feat(openapi): representa schemas do núcleo` |
| T2 | `OApiParam` (localização, nome, obrigatoriedade) | `685df38`, 2026-09-10 12:43:37 — `feat(openapi): representa parâmetros do núcleo` |
| T3 | `OApiBody` (obrigatoriedade, schema, descrição) | `f04d8d7`, 2026-09-10 13:27:43 — `feat(openapi): representa request body do núcleo` |
| T4 | `OApiOper` + `addParam()`/`setBody()` | `2f28edf`, 2026-09-10 14:30:00 — `feat(openapi): associa parâmetros e body às operações` |
| T5 | `OApiResp` + `setSchema()`/`getSchema()` | `eb5c136`, 2026-09-10 14:34:48 — `feat(openapi): associa schema às respostas` |
| T6 | `OApiDoc` + `addSchema()` e resolução transitiva de referências | `8b6bd7a`, 2026-09-10 16:49:58 — `feat(openapi): registra components e valida referências` |
| T7 | `OApiJson` serializando parâmetros, body, respostas e components | `53ae0a7`, 2026-09-10 19:02:33 — `feat(openapi): serializa parâmetros, body e schemas` |
| T8 | Endpoints de demonstração e enriquecimento do `OApiCore` | `8311d4f`, 2026-09-10 19:22:44 — `feat(openapi): publica demonstração de parâmetros e schemas` |

O fixture do núcleo (`tests/openapi-core/custom.openapi.core.test.tlpp`) cresceu de 454 para aproximadamente 970 linhas ao longo das oito tarefas, todas com `assertEquals()` cobrindo os casos RED/GREEN descritos no `spec.md`.

## Decisões e aprendizados

- **Duas classes de bug de encoding foram descobertas e corrigidas nesta sessão**, ambas específicas do fluxo Windows/PowerShell 5.1 deste ambiente (não presentes no marco anterior porque ele não reeditou um arquivo `.tlpp` já convertido para CP-1252 no meio de uma tarefa):
  1. Rodar `utf8-to-cp1252-conversion` sobre um `.tlpp` que já estava em CP-1252 (de uma tarefa anterior) e recebeu edições novas em UTF-8 faz o conversor decodificar o arquivo inteiro como UTF-8, corrompendo os acentos pré-existentes em `?` literal. Corrigido reconvertendo o arquivo inteiro para UTF-8 puro antes de cada edição subsequente, e validado por inspeção de bytes brutos (não apenas pela saída "CONVERTED" do script).
  2. `tests/openapi-core/validate-sources.ps1` estava em UTF-8 sem BOM; o Windows PowerShell 5.1 lê `.ps1` sem BOM assumindo o codepage ANSI do sistema, corrompendo silenciosamente todo literal acentuado do próprio script (mensagens de erro e, mais grave, um padrão de regex que precisava casar com `"Payload inválido."` no fonte real). Corrigido gravando o arquivo com BOM UTF-8.
- **Símbolos do REST TLPP (`oRest:GetPathParamsRequest()`, `GetQueryRequest()`, `GetBodyRequest()`, `SetStatusCode()`, `SetResponse()`) foram validados contra a árvore de fontes padrão do Protheus** (disponível localmente em `D:\PROJETOS\Protheus\TOTVS\...\Fontes`), não apenas contra a skill `tlpp-rest-endpoint-generator` — que, nesse caso, documentava uma variante diferente (`setStatusResponse()` combinado) da que o projeto já usa e da que os fontes de produção confirmam. Essa árvore de fontes foi registrada como nova fonte de verificação no `CLAUDE.md` local (não versionado) e na memória do agente.
- Localização (`in`) de parâmetro é sempre normalizada para minúsculas; identidade de duplicidade é sensível a caixa em `path`/`query` e insensível em `header`, refletindo a natureza case-insensitive de cabeçalhos HTTP.
- `path não obrigatório` é uma pendência acumulada por `validate()`, não uma falha imediata do construtor — decisão tomada a partir do próprio `design.md`, que classifica esse caso junto de outras incompletudes acumuladas (schema incompleto, body sem schema), e não junto das ambiguidades que falham imediatamente.
- A resolução de referências (`$ref`) percorre recursivamente parâmetros, request body, respostas e propriedades aninhadas de objetos/arrays, acumulando contexto de path, verbo e localização — implementada como uma função recursiva auxiliar (`RefPend`) em `OApiDoc`, mantendo o núcleo sem qualquer dependência do formato de saída.

## Rastreabilidade PSCH-01 a PSCH-20

| Requisito | Fonte | Evidência disponível | Estado |
| --- | --- | --- | --- |
| PSCH-01 | `custom.openapi.schema.tlpp` | teste RED/GREEN: discriminante inválido falha com `UserException()` | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-02 | `custom.openapi.schema.tlpp` | teste: `addProp()` preserva nome/schema/obrigatoriedade | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-03 | `custom.openapi.schema.tlpp` | teste: `setItems()` exige schema | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-04 | `custom.openapi.schema.tlpp` | teste: `setRef()` valida nome `[A-Za-z0-9._-]` | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-05 | `custom.openapi.schema.tlpp`, `custom.openapi.document.tlpp` | testes: mutador incompatível, propriedade e componente duplicados falham antes da mutação | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-06 | `custom.openapi.parameter.tlpp` | teste: `cIn` aceita somente `path`/`query`/`header` | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-07 | `custom.openapi.parameter.tlpp`, `custom.openapi.operation.tlpp` | teste: `path` não obrigatório gera pendência acumulada | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-08 | `custom.openapi.operation.tlpp` | teste: `addParam()` rejeita `in`+nome duplicado (case sensível em path/query, insensível em header) | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-09 | `custom.openapi.operation.tlpp` | teste: `getParams()` preserva a ordem de inclusão | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-10 | `custom.openapi.body.tlpp`, `custom.openapi.operation.tlpp` | testes: construção e associação preservam descrição/obrigatoriedade/schema | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-11 | `custom.openapi.operation.tlpp` | teste: segunda chamada a `setBody()` falha sem substituir o original | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-12 | `custom.openapi.response.tlpp`, `custom.openapi.json.tlpp` | teste: `setSchema()` preservado; serialização em `content.application/json.schema` | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-13 | `custom.openapi.document.tlpp` | testes: referência inexistente em parâmetro, body, resposta e propriedade aninhada acumula pendência com contexto | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-14 | `custom.openapi.json.tlpp`, `tests/openapi-core/fixtures/hello-params.json` | teste estrutural via `JsonObject:FromJson()`; fixture corrigida (path `{name}`) e validada pelo validador OpenAPI do projeto, já generalizado | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-15 | `custom.openapi.json.tlpp` | teste: documento com pendência não gera JSON parcial | Implementado — confirmado via PROBAT (2026-09-24) |
| PSCH-16 | `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp` | código revisado; símbolos `oRest` conferidos contra fontes padrão do Protheus | Implementado — confirmado via HTTP real (2026-09-24) |
| PSCH-17 | `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp` | código revisado; lógica replica exatamente o contrato de `spec.md` | Implementado — confirmado via HTTP real (2026-09-24) |
| PSCH-18 | `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp` | código revisado: `FromJson()` e `ValType()` cobrem malformado/ausente/vazio/não textual | Implementado — confirmado via HTTP real (2026-09-24) |
| PSCH-19 | `examples/openapi-core/custom.openapi.core.api.tlpp` | código revisado: registra os três schemas e as duas operações antes de serializar | Implementado — confirmado via HTTP real (2026-09-24) |
| PSCH-20 | segurança do AppServer, sem lógica no fonte | `GET /api/v1/hello/mundo` sem credenciais → `401` real, com `SECURITY=1` | **Confirmado via HTTP real (2026-09-24)** |

## Evidência HTTP

Registrada em 2026-09-24 contra `http://localhost:8084/rest`, usuário `Admin`. Ver "Sessão de validação em runtime" para os cinco resultados completos (401 sem auth, 200 GET, 200 POST válido, 400 POST inválido, documento OpenAPI enriquecido com o path `{name}` corrigido). PSCH-16 a PSCH-20 estão fechados com evidência de execução real, não apenas revisão de código.

## Gates reproduzíveis

Executar a partir da raiz do repositório — todos aprovados (revalidados em 2026-09-24 após a correção do path `{name}`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-core/validate-sources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-core.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-params.json
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
git diff --check
```

Também concluído em 2026-09-24 (antes pendente por depender de AppServer conectado):

```text
advpl-tlpp-compile sobre os 11 fontes .tlpp desta feature — todos [SUCCESS]
Execução do fixture OApiTst via PROBAT — sem THREAD ERROR
curl sem autenticação em /api/v1/hello/mundo → 401
curl autenticado em GET/POST /api/v1/hello → 200/400 conforme o payload
curl autenticado em GET /api/v1/openapi/core → documento enriquecido, validado pelo script do projeto após a correção do path {name}
```

## Segurança dos artefatos

- Apenas as fixtures mínimas e sanitizadas `tests/openapi-core/fixtures/hello-core.json` e `hello-params.json` são versionadas.
- Nenhuma credencial, caminho de ambiente ou configuração local foi adicionada nesta sessão.
- Os novos endpoints seguem o mesmo padrão de erro genérico do núcleo: `POST /api/v1/hello` inválido responde `{"message":"Payload inválido.","status":"error"}`, sem detalhes internos, stack trace ou payload recebido.
- O caminho local dos fontes padrão do Protheus (`D:\PROJETOS\Protheus\TOTVS\...`) foi registrado apenas no `CLAUDE.md` local (não versionado, ignorado pelo `.gitignore`) e na memória do agente — não em nenhum artefato deste repositório.

## Limitações

- Herdadas do núcleo: sem `servers`, `security schemes`, YAML, `enum`, `nullable`, `allOf`/`oneOf`/`anyOf`, múltiplos media types.
- A montagem continua manual; a descoberta automática de annotations TL++ e a leitura de `WSRESTFUL` AdvPL permanecem planejadas como adaptadores futuros. É justamente essa montagem manual que permitiu o bug do path `{name}` (T8 registrou o `GET` no `OApiPath` errado) passar despercebido até a verificação HTTP real — uma descoberta automática a partir do `endpoint=` do `@Get()` teria evitado a divergência por construção.
- `scripts/validate-hello-openapi.ps1` valida apenas os campos fixos (`summary`/`description`/`responses.200.description`) do "path hello"; não valida de forma genérica que todo parâmetro `in: path` tenha um `{...}` correspondente no template do path em qualquer outro endpoint do documento — a checagem de path templates que ele ganhou nesta sessão é específica do path `/api/v1/hello[/{param}]`, não uma regra geral do validador.

## Roteiro editorial

1. **Do núcleo mínimo ao piloto operacional:** por que parâmetros, request body e schemas eram o próximo passo natural depois do Hello World.
2. **Duas armadilhas de encoding no Windows:** o conversor UTF8→CP1252 que corrompe um arquivo já convertido, e o PowerShell 5.1 que precisa de BOM para ler seus próprios scripts corretamente.
3. **Quando confiar em uma skill genérica e quando desconfiar dela:** o caso `oRest:setStatusResponse()` vs. o padrão real encontrado nos fontes de produção do Protheus.
4. **Resolução transitiva de referências sem acoplar o núcleo ao formato de saída:** como `OApiDoc` percorre parâmetros, body, respostas e propriedades aninhadas em busca de `$ref` quebrados.
5. **O custo de montar o documento OpenAPI manualmente:** como um `OApiPath()` reaproveitado por engano para duas rotas diferentes só apareceu na primeira chamada HTTP real — invisível ao PROBAT, ao contrato estático e à leitura de código — e o que isso sugere sobre a prioridade da descoberta automática de rotas via `WSRESTFUL`/annotations.

## Referências internas

- [Especificação da feature](../../.specs/features/openapi-parameters-schemas/spec.md)
- [Decisões do usuário](../../.specs/features/openapi-parameters-schemas/context.md)
- [Design aprovado](../../.specs/features/openapi-parameters-schemas/design.md)
- [Tarefas](../../.specs/features/openapi-parameters-schemas/tasks.md)
- [Plano de implementação](../plans/2026-08-26-openapi-parameters-schemas.md)
- [Diário técnico do núcleo mínimo](openapi-core-model.md)
- [Fixture hello-core.json](../../tests/openapi-core/fixtures/hello-core.json)
- [Fixture hello-params.json](../../tests/openapi-core/fixtures/hello-params.json)
- [Endpoint GET /api/v1/hello/:name](../../examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp)
- [Endpoint POST /api/v1/hello](../../examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp)
- [Endpoint enriquecido GET /api/v1/openapi/core](../../examples/openapi-core/custom.openapi.core.api.tlpp)
