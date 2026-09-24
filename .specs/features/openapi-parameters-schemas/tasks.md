# Parâmetros e schemas OpenAPI - Tarefas

**Design:** `.specs/features/openapi-parameters-schemas/design.md`
**Plano:** `docs/plans/2026-08-26-openapi-parameters-schemas.md`
**Estado:** T1 a T9 implementadas; compilação, PROBAT e verificação HTTP real concluídos em 2026-09-24

> **Nota de verificação (2026-09-10):** todas as tarefas foram implementadas seguindo RED/GREEN, com testes escritos e commitados a cada passo. O contrato estático (`validate-sources.ps1`), as fixtures OpenAPI e todas as regressões existentes passaram em todas as tarefas. Nenhuma compilação real nem execução do PROBAT no `P12_2510` foi feita nesta sessão (o usuário optou por não compilar em cada tarefa).
>
> **Atualização (2026-09-24):** os 11 fontes da feature foram compilados no `P12_2510` e o fixture `OApiTst` rodou via `tlpp.probat.run` sem erros. A verificação HTTP real dos endpoints de demonstração (T8) encontrou e corrigiu um bug de autodocumentação — o `GET /api/v1/hello/:name` estava registrado no documento OpenAPI sob o path `/api/v1/hello` (sem `{name}`) em vez de `/api/v1/hello/{name}` — e revelou o mesmo defeito latente na fixture estática `tests/openapi-core/fixtures/hello-params.json`, ambos corrigidos, junto com uma lacuna correspondente em `scripts/validate-hello-openapi.ps1` (não validava path templates). Compilação, PROBAT e a bateria HTTP completa (401/200/400) estão confirmados. Detalhes em [docs/experiments/openapi-parameters-schemas.md](../../../docs/experiments/openapi-parameters-schemas.md).

## Plano de execução

```text
T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> T7 -> T8 -> T9
```

As tarefas são sequenciais porque cada entidade adiciona um nível ao modelo existente e evolui o mesmo conjunto de testes (`tests/openapi-core/custom.openapi.core.test.tlpp`) e o mesmo contrato (`tests/openapi-core/validate-sources.ps1`). Cada tarefa de fonte inclui teste RED, implementação mínima, conversão Windows-1252, compilação quando autorizada e gate de regressão.

## T1: Implementar `OApiSchema`

**O quê:** criar `OApiSchema` com discriminante explícito (`string`, `integer`, `number`, `boolean`, `object`, `array`, `ref`), mutadores exclusivos por forma e validação acumulada.
**Onde:** `src/core/custom.openapi.schema.tlpp` e teste do núcleo.
**Depende de:** nenhuma (estende o núcleo concluído em `openapi-core-model`).
**Reutiliza:** padrão de entidade estabelecido por `OApiInfo`/`OApiResp`.
**Requisitos:** PSCH-01 a PSCH-05.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `cKind` aceita somente `string`, `integer`, `number`, `boolean`, `object`, `array` ou `ref`, aparado e normalizado para minúsculas; outro valor falha com `UserException()` antes de alterar o objeto;
- [ ] `addProp()` opera exclusivamente em `object`, preserva nome/schema/obrigatoriedade e rejeita propriedade duplicada antes da mutação;
- [ ] `setItems()` opera exclusivamente em `array`, exige schema, e uma segunda chamada falha antes da mutação;
- [ ] `setRef()` opera exclusivamente em `ref`, aceita somente nomes `[A-Za-z0-9._-]` não vazios, e uma segunda chamada falha antes da mutação;
- [ ] mutador incompatível com o discriminante falha imediatamente sem alterar o objeto;
- [ ] `validate()` acumula objeto sem propriedades, array sem `items` e ref sem nome;
- [ ] fonte contém ProtheusDOC completo, está em Windows-1252 sem BOM, e testes/compilação passam.

**Commit:** `feat(openapi): representa schemas do núcleo`

## T2: Implementar `OApiParam`

**O quê:** criar `OApiParam` com nome, localização, obrigatoriedade, schema e descrição.
**Onde:** `src/core/custom.openapi.parameter.tlpp` e teste do núcleo.
**Depende de:** T1.
**Reutiliza:** `OApiSchema`.
**Requisitos:** PSCH-06, PSCH-07.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `cIn` aceita somente `path`, `query` ou `header`, aparado e normalizado para minúsculas; valor desconhecido falha imediatamente;
- [ ] localização `path` sempre resulta em `required` verdadeiro;
- [ ] `cName` é aparado preservando a caixa original;
- [ ] `validate()` acumula campos obrigatórios vazios;
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): representa parâmetros do núcleo`

## T3: Implementar `OApiBody`

**O quê:** criar `OApiBody` com obrigatoriedade, schema e descrição do request body.
**Onde:** `src/core/custom.openapi.body.tlpp` e teste do núcleo.
**Depende de:** T1.
**Reutiliza:** `OApiSchema`.
**Requisitos:** PSCH-10 (construção).
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] obrigatoriedade, schema e descrição informados são preservados sem alteração;
- [ ] `validate()` acumula body sem schema;
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): representa request body do núcleo`

## T4: Associar parâmetros e body em `OApiOper`

**O quê:** estender `OApiOper` com `addParam()` e `setBody()`, preservando unicidade e ordem.
**Onde:** `src/core/custom.openapi.operation.tlpp` e teste do núcleo.
**Depende de:** T2, T3.
**Reutiliza:** `OApiParam`, `OApiBody`, padrão de conflito já usado em `addResp()`.
**Requisitos:** PSCH-08, PSCH-09, PSCH-10 (associação), PSCH-11.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] parâmetro com `in + name` já existente é rejeitado sem substituir o original; identidade é sensível a caixa em `path`/`query` e insensível em `header`;
- [ ] a ordem de inclusão dos parâmetros é preservada para serialização;
- [ ] `setBody()` associa descrição, obrigatoriedade e schema do request body;
- [ ] uma segunda chamada a `setBody()` falha sem substituir o body original;
- [ ] `validate()` agrega as pendências de parâmetros e do body;
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): associa parâmetros e body às operações`

## T5: Associar schema em `OApiResp`

**O quê:** estender `OApiResp` com `setSchema()`/`getSchema()` opcionais para o conteúdo JSON da resposta.
**Onde:** `src/core/custom.openapi.response.tlpp` e teste do núcleo.
**Depende de:** T1.
**Reutiliza:** `OApiSchema`.
**Requisitos:** PSCH-12 (preparação).
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] schema opcional informado é preservado e recuperável;
- [ ] resposta sem schema continua válida e sem pendências adicionais;
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): associa schema às respostas`

## T6: Registrar components e validar referências em `OApiDoc`

**O quê:** estender `OApiDoc` com `addSchema()` e validação transitiva de referências.
**Onde:** `src/core/custom.openapi.document.tlpp` e teste do núcleo.
**Depende de:** T4, T5.
**Reutiliza:** `OApiSchema`, agregação de pendências já usada para paths/operações/respostas.
**Requisitos:** PSCH-05 (componente duplicado), PSCH-13.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `addSchema(cName, oSchema)` registra um componente com nome único; nome duplicado falha antes da mutação;
- [ ] nomes de componentes aceitam somente `[A-Za-z0-9._-]` e não podem ser vazios;
- [ ] `validate()` resolve referências de parâmetros, body, respostas e propriedades contra o registro de components;
- [ ] toda referência inexistente gera pendência acumulada com contexto (path, verbo, parâmetro/resposta/propriedade);
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): registra components e valida referências`

## T7: Serializar parâmetros, body e schemas em `OApiJson`

**O quê:** estender `OApiJson:toJson()` para publicar `parameters`, `requestBody`, `content.application/json.schema` das respostas e `components/schemas`.
**Onde:** `src/core/custom.openapi.json.tlpp`, `tests/openapi-core/fixtures/hello-params.json` e teste do núcleo.
**Depende de:** T6.
**Reutiliza:** `JsonObject():New()`, `ToJson()` e `scripts/validate-hello-openapi.ps1`.
**Requisitos:** PSCH-14, PSCH-15.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] documento com pendência continua sendo rejeitado antes de qualquer saída parcial;
- [ ] `parameters` são serializados com `in`, `name`, `required` e `schema`, preservando a ordem de inclusão;
- [ ] `requestBody` é serializado em `content.application/json.schema`;
- [ ] respostas com schema são serializadas em `content.application/json.schema`;
- [ ] `components/schemas` são serializados com objetos, arrays, primitivos e `$ref` para `#/components/schemas/<nome>`;
- [ ] fixture cobre múltiplos parâmetros, objeto, array, `$ref`, request body e respostas com schema;
- [ ] teste compara estrutura via `JsonObject`, não texto bruto;
- [ ] testes, encoding e compilação passam.

**Commit:** `feat(openapi): serializa parâmetros, body e schemas`

## T8: Publicar o endpoint de demonstração

**O quê:** criar `GET /api/v1/hello/{name}` e `POST /api/v1/hello`, e enriquecer `GET /api/v1/openapi/core` com as duas operações e os três schemas reutilizáveis.
**Onde:** `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp`, `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp`, `examples/openapi-core/custom.openapi.core.api.tlpp` e contratos locais.
**Depende de:** T7.
**Reutiliza:** padrão de `examples/openapi-core/custom.openapi.core.api.tlpp`.
**Requisitos:** PSCH-16 a PSCH-20.
**Skills:** `tlpp-rest-endpoint-generator`, `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [ ] `GET /api/v1/hello/{name}` usa o parâmetro de path `name` e aceita `language` opcional na query, com default `TL++`;
- [ ] `POST /api/v1/hello` com `HelloRequest` válido responde `200` com `HelloResponse` (`message = "Hello " + name`, `language` efetiva, `status = "success"`);
- [ ] `POST /api/v1/hello` com JSON malformado ou `name` ausente/vazio/não textual responde `400` com `ErrorResponse` genérico, sem detalhes internos;
- [ ] `GET /api/v1/openapi/core` retorna as duas operações e os três schemas reutilizáveis (`HelloRequest`, `HelloResponse`, `ErrorResponse`);
- [ ] chamada sem autenticação com `SECURITY=1` preserva HTTP `401`;
- [ ] nenhum endpoint usa `tlpp.doc.generate()` nem filesystem;
- [ ] JSON capturado passa no validador OpenAPI do projeto.

**Commit:** `feat(openapi): publica demonstração de parâmetros e schemas`

## T9: Registrar evidências e atualizar o roadmap

**O quê:** documentar resultados, decisões, limitações, comandos e roteiro editorial.
**Onde:** README, spec/tasks da feature e diário técnico correspondente.
**Depende de:** T8.
**Reutiliza:** formato de `docs/experiments/openapi-core-model.md`.
**Requisitos:** rastreabilidade de PSCH-01 a PSCH-20.
**Skills:** `verification-before-completion`.

**Concluída quando:**

- [x] cada requisito PSCH-01 a PSCH-20 está marcado com evidência verificável (ver diário técnico);
- [x] versão do ambiente alvo e o estado real do PROBAT/harness estão registrados — execução não realizada nesta sessão, registrada explicitamente como pendência;
- [x] README indica o incremento de parâmetros e schemas com seu estado real (implementado, pendente de validação em runtime);
- [x] nenhum artefato sensível ou credencial é versionado;
- [x] gate completo (contrato estático + regressões + as duas fixtures) passa.

**Commit:** `docs(openapi): registra parâmetros e schemas validados`

## Validações pré-aprovação

- **Granularidade:** cada tarefa entrega uma classe, extensão de classe, conjunto de endpoints ou documentação.
- **Dependências:** o diagrama linear corresponde aos campos `Depende de`; `OApiSchema` (T1) é o único pré-requisito comum às demais classes novas (T2, T3), que convergem em `OApiOper` (T4) antes de `OApiDoc` (T6) e `OApiJson` (T7).
- **Testes co-localizados:** toda tarefa de fonte evolui o teste do núcleo e exige compilação após encoding.
- **Cobertura:** PSCH-01 a PSCH-20 estão associados a pelo menos uma tarefa, replicando a rastreabilidade do `spec.md`.
