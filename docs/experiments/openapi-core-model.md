# Núcleo mínimo do modelo OpenAPI

## Ambiente validado

| Componente | Versão |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 (build 7.00.240223P) |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 |

Somente as versões necessárias à reprodução foram registradas. Configuração integral do AppServer, caminhos locais, usuários e dados de autenticação não fazem parte dos artefatos versionados.

## Objetivo e resultado

O experimento implementou um vertical slice manual capaz de representar, validar e serializar em JSON um documento OpenAPI 3.0.3 para `GET /api/v1/hello`. O endpoint de demonstração `GET /api/v1/openapi/core` publica o resultado sem depender de `tlpp.doc.generate()` e sem acoplar o núcleo ao objeto REST.

O marco contém seis classes no namespace `custom.openapi.core`:

| Classe | Responsabilidade |
| --- | --- |
| `OApiInfo` | preservar e validar título, descrição e versão da API. |
| `OApiResp` | preservar e validar código e descrição de resposta. |
| `OApiOper` | normalizar o verbo, manter metadados e respostas únicas. |
| `OApiPath` | validar o path e manter operações únicas por verbo. |
| `OApiDoc` | representar a raiz 3.0.3 e acumular pendências transitivas. |
| `OApiJson` | bloquear documentos inválidos e serializar a árvore completa. |

```text
OApiInfo -> OApiDoc -> OApiPath -> OApiOper -> OApiResp
                 |                         |
                 +------ validate() -------+
                              |
                           OApiJson
                              |
                      JSON OpenAPI 3.0.3
                              |
                  GET /api/v1/openapi/core
```

O endpoint em `examples/` é apenas um cliente do núcleo: monta o Hello World pelas APIs públicas, chama o serializador e traduz uma falha inesperada para uma resposta genérica. A infraestrutura REST continua responsável pela autenticação.

## Evolução TDD

Os horários abaixo são reproduções das evidências preservadas no console e no histórico Git. Quando o registro disponível não contém horário ou contagem do PROBAT, isso é indicado explicitamente.

| Tarefa | RED | GREEN | Commit |
| --- | --- | --- | --- |
| T1 — harness | Em 2026-08-24 13:47:40, a falha deliberada produziu `ok: 0`, `err: 1`. | Execução iniciada às 14:28:19 e encerrada às 14:28:24 sem erro de assert. | `f25a72a`, 2026-08-24 14:37:57 — `test(openapi): prepara testes do núcleo tlpp`. |
| T2 — info | Em 2026-08-24 17:25:27, `invalid class OAPIINFO`, com `ok: 1`, `err: 1`. | Execuções concluídas sem erro às 17:41:07 e, após endurecimento do fixture, às 18:05:17. | `4bfa0b0`, 2026-08-24 18:06:39 — `feat(openapi): adiciona informações do documento`. |
| T3 — respostas | Em 2026-08-25 08:59:51, `invalid class OAPIRESP`, com `ok: 8`, `err: 1`. | Execução encerrada às 09:17:15 sem erro de assert; o registro não apresenta a contagem final. | `e72e95c`, 2026-08-25 09:21:49 — `feat(openapi): adiciona respostas ao modelo`. |
| T4 — operações | Em 2026-08-25 09:40:40, `invalid class OAPIOPER`, com `ok: 14`, `err: 1`. | Execução encerrada às 09:48:10 sem erro; após endurecimento dos testes, novo GREEN às 10:03:25. Os registros não apresentam a contagem final. | `596c61b`, 2026-08-25 10:05:17 — `feat(openapi): adiciona operações e respostas`. |
| T5 — paths | Em 2026-08-25 10:18:04, `invalid class OAPIPATH`, com `ok: 42`, `err: 1`. | Execução encerrada às 10:46:23 sem erro de assert; o registro não apresenta a contagem final. | `ad36e1d`, 2026-08-25 10:56:12 — `feat(openapi): adiciona paths ao modelo`. |
| T6 — documento | A revisão retornou ao RED às 13:57 com sete asserts para duplicidade, reutilização e validação transitiva. | GREEN final confirmado em 2026-08-25 14:24:22. | `afcedd9`, 2026-08-25 14:30:15 — `feat(openapi): adiciona documento raiz`. |
| T7 — JSON | Em 2026-08-25 14:41:35, `invalid class OAPIJSON`, com `ok: 87`, `err: 1`. | Serialização estrutural e cobertura plural passaram no RPO às 16:30:23; o registro não apresenta a contagem final. | `c7739f0`, 2026-08-25 16:59:40 — `feat(openapi): serializa modelo como json`. |
| T8 — endpoint | O gate estático falhou especificamente pela ausência do fonte do endpoint. | Contrato estático e compilação passaram; em 2026-08-25, o HTTP `401` foi registrado às 17:23:43 e o `200` às 17:23:59 (`-03:00`), seguido da validação estrutural do corpo. | `1e616ac`, 2026-08-25 17:28:37 — `feat(openapi): publica demonstração do núcleo`. |

O fixture final contém 98 chamadas a `assertEquals()`. Esse número descreve o fonte atual e não é apresentado como contagem de uma execução do PROBAT.

## Decisões e aprendizados

- O modelo próprio foi separado da descoberta e da saída. Assim, futuros adaptadores TL++ e AdvPL podem alimentar o mesmo contrato sem conhecer `JsonObject` ou REST.
- Invariantes ambíguas falham antes da mutação: path inválido, verbo não suportado, verbo repetido e resposta repetida. Pendências de completude são acumuladas por `validate()`.
- Getters de coleções usam `AClone()` para impedir alterações externas na composição dos arrays internos; os objetos contidos continuam compartilhados, pois a cópia é rasa.
- `OApiJson` valida antes de criar qualquer objeto JSON. Todas as pendências são concatenadas em ordem, e a falha não devolve conteúdo parcial.
- Os testes comparam a estrutura parseada, não a ordem textual das propriedades. Dois paths, duas operações em um mesmo path e múltiplas respostas exercitam todos os laços do serializador.
- O identificador interno inicialmente planejado como `cVer` conflitou com uma macro existente em `sigawin.ch`. O campo foi renomeado para `cApiVer`, mantendo o método público curto `getVer()`. A ocorrência reforçou a necessidade de validar também conflitos de preprocessador.
- A revisão T6 foi tratada como uma nova etapa RED/GREEN. Ela acrescentou prova de rejeição antes da mutação, reutilização do documento e validação transitiva com contexto de path, verbo e código, inclusive em múltiplos paths e ordem determinística.

## Rastreabilidade CORE-01 a CORE-18

As referências de teste apontam para `tests/openapi-core/custom.openapi.core.test.tlpp`; o contrato estático complementar está em `tests/openapi-core/validate-sources.ps1`.

| Requisito | Fonte | Evidência de teste ou HTTP | Estado |
| --- | --- | --- | --- |
| CORE-01 | `src/core/custom.openapi.document.tlpp` | asserção de `getOpenApi()` e JSON `openapi = 3.0.3` | Validado |
| CORE-02 | `src/core/custom.openapi.info.tlpp` | getters preservam título, descrição e versão | Validado |
| CORE-03 | `src/core/custom.openapi.path.tlpp`, `custom.openapi.operation.tlpp` | asserções de path, verbo normalizado, resumo e descrição | Validado |
| CORE-04 | `src/core/custom.openapi.response.tlpp` | asserções de código `200` e descrição | Validado |
| CORE-05 | cinco entidades do modelo e endpoint | fixture e corpo HTTP contêm `GET /api/v1/hello`/`200` | Validado |
| CORE-06 | `custom.openapi.path.tlpp` | path sem `/` rejeitado com diagnóstico | Validado |
| CORE-07 | `custom.openapi.operation.tlpp` | verbo `CONNECT` rejeitado com diagnóstico | Validado |
| CORE-08 | `custom.openapi.path.tlpp` | verbo duplicado rejeitado; primeira operação preservada | Validado |
| CORE-09 | `custom.openapi.operation.tlpp` | código duplicado rejeitado; primeira resposta preservada | Validado |
| CORE-10 | `OApiPath` e `OApiDoc` | objetos recebem novas inclusões válidas após falhas | Validado |
| CORE-11 | `custom.openapi.info.tlpp`, `custom.openapi.document.tlpp` | título, versão e ausência de paths retornados na ordem esperada | Validado |
| CORE-12 | `OApiOper`, `OApiPath`, `OApiDoc` | pendências transitivas incluem path, verbo e resposta | Validado |
| CORE-13 | `src/core/custom.openapi.json.tlpp` | documento incompleto lança antes da serialização | Validado |
| CORE-14 | `custom.openapi.json.tlpp` | `cJson` permanece vazio após a rejeição | Validado |
| CORE-15 | `custom.openapi.json.tlpp` | `FromJson()` e asserts estruturais; fixture aceita pelo validador | Validado |
| CORE-16 | `examples/openapi-core/custom.openapi.core.api.tlpp` | chamada autenticada: HTTP `200` e `application/json` | Validado |
| CORE-17 | endpoint e `tests/openapi-core/fixtures/hello-core.json` | corpo aceito como OpenAPI 3.0.3 com Hello World | Validado |
| CORE-18 | configuração de segurança do AppServer, sem lógica no fonte | chamada sem autenticação: HTTP `401` | Validado |

## Evidência HTTP

O endpoint herdou a segurança do AppServer: a chamada sem autenticação retornou HTTP `401`. A chamada autenticada retornou HTTP `200`, `Content-Type: application/json` e um corpo aceito pelo validador do projeto. A validação estrutural confirmou:

- `openapi` igual a `3.0.3`;
- `info.title`, `info.description` e `info.version` iguais aos valores do exemplo;
- `paths[/api/v1/hello].get` com resumo e descrição;
- `paths[/api/v1/hello].get.responses[200].description` igual a `Hello World retornado com sucesso.`.

Nenhum dado de autenticação ou cabeçalho de autorização foi registrado.

## Gates reproduzíveis

Executar a partir da raiz do repositório:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-core/validate-sources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-core.json
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
git diff --check
```

> **Nota (2026-09-24):** os comandos acima referenciam os scripts `.ps1` originais desta sessão, removidos numa migração posterior para Python (mesma lógica e mensagens). Para reproduzir estes gates hoje, use os equivalentes `.py` com a mesma sintaxe de argumentos: `python tests/openapi-core/validate-sources.py`, `python scripts/validate-hello-openapi.py --path ...`, `python tests/openapi-normalization/run-tests.py`, `python tests/hello-world/validate-sources.py --target ...`. Ver [docs/experiments/openapi-parameters-schemas.md](openapi-parameters-schemas.md) para o registro da migração.

Na validação registrada para este marco, o normalizador manteve sua regressão com **15 testes aprovados de 15**. O contrato do núcleo também verifica includes, namespace, ProtheusDOC, encoding Windows-1252 sem BOM, APIs públicas e ausência de filesystem, credenciais, `tlpp.doc.generate()` e outras dependências proibidas.

## Segurança dos artefatos

- Apenas a fixture mínima e sanitizada `tests/openapi-core/fixtures/hello-core.json` é versionada.
- Respostas completas do ambiente, arquivos gerados, configurações locais e logs extensos permanecem fora do repositório.
- O endpoint não contém autenticação própria, segredos, caminhos de ambiente, logging de exceção ou detalhes de stack no corpo de erro.
- A resposta HTTP `500` é deliberadamente genérica: `Falha ao gerar o documento OpenAPI.`.

## Limitações

- O núcleo representa somente `openapi`, `info`, `paths`, operações e respostas mínimas; ainda não cobre parâmetros, request bodies, schemas, segurança, `servers` ou `components`.
- A saída deste marco é JSON compacto. YAML e pretty-print permanecem fora do núcleo.
- A montagem é manual. A descoberta de annotations TL++ e a leitura de serviços `WSRESTFUL` AdvPL continuam planejadas como adaptadores independentes.
- O núcleo não importa nem normaliza o YAML nativo; o normalizador existente permanece um utilitário separado.
- O PROBAT é executado no RPO pelo fluxo disponível no TDS/AppServer; os scripts locais validam contratos, mas não substituem essa execução de runtime.

## Roteiro editorial

1. **Do Hello World ao problema real:** ambiente validado, REST-DOC, YAML duplicado e ausência do serviço AdvPL na descoberta nativa.
2. **TDD com PROBAT em TL++:** harness, ciclo RED/GREEN, encoding e o conflito da macro `cVer`.
3. **Modelando OpenAPI por composição:** seis classes, invariantes imediatas, validação acumulada e cópias defensivas.
4. **Serialização segura com `JsonObject`:** validação antes da saída, testes estruturais e cobertura plural dos laços.
5. **Publicando o núcleo por REST:** separação entre domínio e transporte, HTTP `401`/`200` e tratamento seguro de erros.
6. **Próximos adaptadores:** descoberta de annotations TL++ e estratégia explícita para APIs `WSRESTFUL` AdvPL.

## Referências internas

- [Especificação do núcleo](../../.specs/features/openapi-core-model/spec.md)
- [Design do núcleo](../../.specs/features/openapi-core-model/design.md)
- [Plano de implementação](../plans/2026-08-21-openapi-core-model.md)
- [Experimento Hello World](hello-world.md)
- [Fixture JSON sanitizada](../../tests/openapi-core/fixtures/hello-core.json)
- [Endpoint de demonstração](../../examples/openapi-core/custom.openapi.core.api.tlpp)
