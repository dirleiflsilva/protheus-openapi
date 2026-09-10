# Parâmetros e schemas do modelo OpenAPI

## Ambiente alvo (não executado nesta sessão)

| Componente | Versão alvo |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 (build 7.00.240223P) |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 |

Esta tabela repete o ambiente registrado em [docs/experiments/openapi-core-model.md](openapi-core-model.md) porque este incremento estende o mesmo núcleo. **Diferente daquele marco, nenhuma compilação nem execução do PROBAT foi realizada nesta sessão** — o usuário optou explicitamente por não compilar em cada uma das oito tarefas de implementação. As versões acima descrevem o alvo pretendido, não um ambiente efetivamente exercitado.

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

Todas as tarefas seguiram RED (teste escrito antes da implementação) → GREEN (implementação mínima) → conversão CP-1252 → contrato estático → regressões → commit. **Nenhuma delas foi confirmada por uma execução real do PROBAT**; "GREEN" aqui significa que a implementação foi escrita para satisfazer as asserções, não que elas foram executadas com sucesso no RPO.

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
| PSCH-01 | `custom.openapi.schema.tlpp` | teste RED/GREEN: discriminante inválido falha com `UserException()` | Implementado — PROBAT não executado |
| PSCH-02 | `custom.openapi.schema.tlpp` | teste: `addProp()` preserva nome/schema/obrigatoriedade | Implementado — PROBAT não executado |
| PSCH-03 | `custom.openapi.schema.tlpp` | teste: `setItems()` exige schema | Implementado — PROBAT não executado |
| PSCH-04 | `custom.openapi.schema.tlpp` | teste: `setRef()` valida nome `[A-Za-z0-9._-]` | Implementado — PROBAT não executado |
| PSCH-05 | `custom.openapi.schema.tlpp`, `custom.openapi.document.tlpp` | testes: mutador incompatível, propriedade e componente duplicados falham antes da mutação | Implementado — PROBAT não executado |
| PSCH-06 | `custom.openapi.parameter.tlpp` | teste: `cIn` aceita somente `path`/`query`/`header` | Implementado — PROBAT não executado |
| PSCH-07 | `custom.openapi.parameter.tlpp`, `custom.openapi.operation.tlpp` | teste: `path` não obrigatório gera pendência acumulada | Implementado — PROBAT não executado |
| PSCH-08 | `custom.openapi.operation.tlpp` | teste: `addParam()` rejeita `in`+nome duplicado (case sensível em path/query, insensível em header) | Implementado — PROBAT não executado |
| PSCH-09 | `custom.openapi.operation.tlpp` | teste: `getParams()` preserva a ordem de inclusão | Implementado — PROBAT não executado |
| PSCH-10 | `custom.openapi.body.tlpp`, `custom.openapi.operation.tlpp` | testes: construção e associação preservam descrição/obrigatoriedade/schema | Implementado — PROBAT não executado |
| PSCH-11 | `custom.openapi.operation.tlpp` | teste: segunda chamada a `setBody()` falha sem substituir o original | Implementado — PROBAT não executado |
| PSCH-12 | `custom.openapi.response.tlpp`, `custom.openapi.json.tlpp` | teste: `setSchema()` preservado; serialização em `content.application/json.schema` | Implementado — PROBAT não executado |
| PSCH-13 | `custom.openapi.document.tlpp` | testes: referência inexistente em parâmetro, body, resposta e propriedade aninhada acumula pendência com contexto | Implementado — PROBAT não executado |
| PSCH-14 | `custom.openapi.json.tlpp`, `tests/openapi-core/fixtures/hello-params.json` | teste estrutural via `JsonObject:FromJson()`; fixture validada pelo validador OpenAPI do projeto | Implementado — verificado estruturalmente; PROBAT não executado |
| PSCH-15 | `custom.openapi.json.tlpp` | teste: documento com pendência não gera JSON parcial | Implementado — PROBAT não executado |
| PSCH-16 | `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp` | código revisado; símbolos `oRest` conferidos contra fontes padrão do Protheus | Implementado — não compilado nem executado via HTTP |
| PSCH-17 | `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp` | código revisado; lógica replica exatamente o contrato de `spec.md` | Implementado — não compilado nem executado via HTTP |
| PSCH-18 | `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp` | código revisado: `FromJson()` e `ValType()` cobrem malformado/ausente/vazio/não textual | Implementado — não compilado nem executado via HTTP |
| PSCH-19 | `examples/openapi-core/custom.openapi.core.api.tlpp` | código revisado: registra os três schemas e as duas operações antes de serializar | Implementado — não compilado nem executado via HTTP |
| PSCH-20 | segurança do AppServer, sem lógica no fonte | **sem evidência** — requer chamada HTTP real sem autenticação | **Pendente** — não verificável sem AppServer |

## Evidência HTTP

**Nenhuma.** Diferente do marco `openapi-core-model` (que registrou HTTP `401`/`200` reais), esta sessão não compilou nenhum fonte nem chamou nenhum endpoint. PSCH-16 a PSCH-20 foram implementados e revisados contra os fontes padrão do Protheus, mas permanecem sem qualquer evidência de execução. A verificação HTTP completa (401 sem autenticação, 200 para GET/POST válidos, 400 para POST inválido, documento OpenAPI enriquecido) é o primeiro passo pendente antes de considerar este incremento validado.

## Gates reproduzíveis

Executar a partir da raiz do repositório — todos aprovados nesta sessão:

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

Ainda pendente (requer AppServer conectado):

```text
advpl-tlpp-compile sobre todos os fontes .tlpp desta feature
Execução do fixture OApiTst via PROBAT
curl sem autenticação em /api/v1/hello/:name → esperado 401
curl autenticado em GET/POST /api/v1/hello → esperado 200/400 conforme o payload
curl autenticado em GET /api/v1/openapi/core → documento enriquecido validado pelo script do projeto
```

## Segurança dos artefatos

- Apenas as fixtures mínimas e sanitizadas `tests/openapi-core/fixtures/hello-core.json` e `hello-params.json` são versionadas.
- Nenhuma credencial, caminho de ambiente ou configuração local foi adicionada nesta sessão.
- Os novos endpoints seguem o mesmo padrão de erro genérico do núcleo: `POST /api/v1/hello` inválido responde `{"message":"Payload inválido.","status":"error"}`, sem detalhes internos, stack trace ou payload recebido.
- O caminho local dos fontes padrão do Protheus (`D:\PROJETOS\Protheus\TOTVS\...`) foi registrado apenas no `CLAUDE.md` local (não versionado, ignorado pelo `.gitignore`) e na memória do agente — não em nenhum artefato deste repositório.

## Limitações

- Herdadas do núcleo: sem `servers`, `security schemes`, YAML, `enum`, `nullable`, `allOf`/`oneOf`/`anyOf`, múltiplos media types.
- A montagem continua manual; a descoberta automática de annotations TL++ e a leitura de `WSRESTFUL` AdvPL permanecem planejadas como adaptadores futuros.
- **Nada foi compilado ou executado em runtime nesta sessão.** Este é o maior risco residual do incremento: os símbolos usados nos endpoints (T8) foram validados por leitura contra código de produção real, mas nunca por uma compilação efetiva no `P12_2510`.
- PSCH-20 (HTTP `401`) não pode ser considerado atendido sem uma verificação real contra o AppServer.

## Roteiro editorial

1. **Do núcleo mínimo ao piloto operacional:** por que parâmetros, request body e schemas eram o próximo passo natural depois do Hello World.
2. **Duas armadilhas de encoding no Windows:** o conversor UTF8→CP1252 que corrompe um arquivo já convertido, e o PowerShell 5.1 que precisa de BOM para ler seus próprios scripts corretamente.
3. **Quando confiar em uma skill genérica e quando desconfiar dela:** o caso `oRest:setStatusResponse()` vs. o padrão real encontrado nos fontes de produção do Protheus.
4. **Resolução transitiva de referências sem acoplar o núcleo ao formato de saída:** como `OApiDoc` percorre parâmetros, body, respostas e propriedades aninhadas em busca de `$ref` quebrados.
5. **O que falta para chamar isso de validado:** compilação, PROBAT e a bateria HTTP completa, incluindo o `401`.

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
