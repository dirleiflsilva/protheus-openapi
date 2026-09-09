# Parâmetros e schemas OpenAPI - Plano de implementação

> **Para o executor:** SUB-SKILL OBRIGATÓRIA: usar `executing-plans` para implementar este plano tarefa por tarefa.

**Objetivo:** estender o núcleo `custom.openapi.core` com parâmetros `path`/`query`/`header`, schemas primitivos/objeto/array/`$ref`, request body e `components/schemas`, mantendo o modelo independente de REST e `JsonObject`, e demonstrar o incremento por endpoints GET e POST reais.

**Arquitetura:** três classes novas (`OApiSchema`, `OApiParam`, `OApiBody`) somam-se às seis já existentes; `OApiOper`, `OApiResp`, `OApiDoc` e `OApiJson` são estendidas para compor e serializar as novas estruturas. `OApiJson` continua sendo a única camada que conhece o formato de saída.

**Stack:** TL++, `tlpp-core.th`, `tlpp-rest.th` somente nos exemplos, `tlpp-probat.th`, `JsonObject`, PowerShell e AppServer/RPO `P12_2510`.

---

### Tarefa 1: Criar `OApiSchema`

**Arquivos:**

- Criar: `src/core/custom.openapi.schema.tlpp`
- Modificar: `tests/openapi-core/custom.openapi.core.test.tlpp`
- Modificar: `tests/openapi-core/validate-sources.ps1`

**Passo 1: escrever testes RED**

Cobrir `cKind` aceitando somente `string`, `integer`, `number`, `boolean`, `object`, `array` ou `ref` (aparado e normalizado para minúsculas); discriminante desconhecido falhando antes de alterar o objeto. Cobrir `addProp()` exclusivo de `object` (nome, schema e obrigatoriedade preservados; propriedade duplicada rejeitada), `setItems()` exclusivo de `array` (exige schema; segunda chamada falha) e `setRef()` exclusivo de `ref` (nome restrito a `[A-Za-z0-9._-]`, não vazio; segunda chamada falha). Cobrir mutador incompatível com o discriminante falhando imediatamente. Cobrir `validate()` acumulando objeto sem propriedades, array sem `items` e ref sem nome.

**Passo 2: implementar o mínimo GREEN**

Criar `OApiSchema` com dado privado de discriminante e coleções internas para propriedades/items/ref. Validar o mutador contra o discriminante antes de qualquer `AAdd`/atribuição; usar `UserException()` para toda ambiguidade. ProtheusDOC completo em todos os métodos; Locais declarados no início.

**Passo 3: validar**

Executar contrato local, converter para Windows-1252 sem BOM, compilar quando autorizado e rodar os testes no RPO.

**Passo 4: commit**

```text
feat(openapi): representa schemas do núcleo
```

### Tarefa 2: Criar `OApiParam`

**Arquivos:**

- Criar: `src/core/custom.openapi.parameter.tlpp`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Cobrir `cIn` aceitando somente `path`, `query` ou `header` (aparado e normalizado para minúsculas); valor desconhecido falhando. Cobrir `path` forçando `required` verdadeiro. Cobrir `cName` aparado com caixa preservada. Cobrir `validate()` para campos obrigatórios vazios.

**Passo 2: implementar o mínimo GREEN**

Implementar `new(cName, cIn, lReq, oSchema, cDesc)`, getters e `validate()`. Não definir aqui a checagem de duplicidade entre parâmetros — ela pertence a `OApiOper` (Tarefa 4).

**Passo 3: validar e commitar**

Executar o gate da tarefa e criar `feat(openapi): representa parâmetros do núcleo`.

### Tarefa 3: Criar `OApiBody`

**Arquivos:**

- Criar: `src/core/custom.openapi.body.tlpp`
- Modificar: teste e contrato do núcleo

**Passos TDD:**

1. RED: construção preservando `required`, `schema` e descrição; `validate()` acumulando body sem schema.
2. GREEN: implementar `new(lReq, oSchema, cDesc)`, getters e `validate()`.
3. Executar contratos, encoding, compilação e testes.
4. Commit: `feat(openapi): representa request body do núcleo`.

### Tarefa 4: Estender `OApiOper` com parâmetros e body

**Arquivos:**

- Modificar: `src/core/custom.openapi.operation.tlpp`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Cobrir `addParam()` rejeitando duplicidade por `in + name` (identidade sensível a caixa em `path`/`query`, insensível em `header`) sem substituir o parâmetro original. Cobrir preservação da ordem de inclusão para serialização. Cobrir `setBody()` associando o request body; segunda chamada a `setBody()` falhando sem substituir o body original. Cobrir `validate()` agregando pendências de parâmetros e do body.

**Passo 2: implementar o mínimo GREEN**

Adicionar coleção privada de parâmetros e dado privado de body; validar duplicidade e substituição antes de qualquer mutação, como já ocorre em `addResp()`.

**Passo 3: validar e commitar**

Executar o gate da tarefa e criar `feat(openapi): associa parâmetros e body às operações`.

### Tarefa 5: Estender `OApiResp` com schema

**Arquivos:**

- Modificar: `src/core/custom.openapi.response.tlpp`
- Modificar: teste e contrato do núcleo

**Passos TDD:**

1. RED: `setSchema()`/`getSchema()` preservando um schema opcional; resposta sem schema continuando válida.
2. GREEN: adicionar dado privado opcional e os métodos, sem alterar o comportamento existente de `validate()`.
3. Executar contratos, encoding, compilação e testes.
4. Commit: `feat(openapi): associa schema às respostas`.

### Tarefa 6: Estender `OApiDoc` com components e referências

**Arquivos:**

- Modificar: `src/core/custom.openapi.document.tlpp`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Cobrir `addSchema(cName, oSchema)` registrando um componente único; nome duplicado falhando antes de qualquer mutação; nomes restritos a `[A-Za-z0-9._-]` não vazios. Cobrir `validate()` resolvendo referências de parâmetros, body, respostas e propriedades contra o registro de components, acumulando pendência com contexto (path, verbo, parâmetro/resposta/propriedade) para toda referência inexistente.

**Passo 2: implementar o mínimo GREEN**

Adicionar registro privado de components; percorrer transitivamente paths, operações, parâmetros, body e respostas ao validar, reaproveitando o padrão de agregação já usado para paths/operações/respostas.

**Passo 3: validar e commitar**

Executar o gate da tarefa e criar `feat(openapi): registra components e valida referências`.

### Tarefa 7: Estender `OApiJson`

**Arquivos:**

- Modificar: `src/core/custom.openapi.json.tlpp`
- Criar: `tests/openapi-core/fixtures/hello-params.json`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Testar que `toJson()` continua recusando documento incompleto antes de qualquer saída parcial. Testar a estrutura esperada para um documento com múltiplos parâmetros, objeto, array, `$ref`, request body, respostas com schema e `components/schemas`. Interpretar o JSON resultante em `JsonObject` antes das asserções.

**Passo 2: implementar o mínimo GREEN**

Serializar `parameters` (in, name, required, schema, preservando ordem), `requestBody` em `content.application/json.schema`, `responses[].content.application/json.schema` quando houver schema, e `components/schemas` com `$ref` apontando para `#/components/schemas/<nome>`.

**Passo 3: validação externa**

Salvar a fixture sanitizada e validá-la com:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-params.json
```

**Passo 4: validar e commitar**

Executar contratos, encoding, compilação e testes; criar `feat(openapi): serializa parâmetros, body e schemas`.

### Tarefa 8: Publicar os endpoints de demonstração

**Arquivos:**

- Criar: `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp`
- Criar: `examples/openapi-parameters-schemas/custom.openapi.hello.post.tlpp`
- Modificar: `examples/openapi-core/custom.openapi.core.api.tlpp`
- Modificar: `tests/openapi-core/validate-sources.ps1`

**Passo 1: escrever o contrato RED**

Exigir `GET /api/v1/hello/{name}` com parâmetro de path `name` e query opcional `language`; `POST /api/v1/hello` recebendo `HelloRequest`; `GET /api/v1/openapi/core` enriquecido com as duas operações e os três schemas reutilizáveis (`HelloRequest`, `HelloResponse`, `ErrorResponse`); ausência de `tlpp.doc.generate()` ou filesystem em qualquer endpoint.

**Passo 2: implementar os endpoints**

`language` assume `TL++` quando ausente ou vazia. GET e POST válidos retornam `200` com `HelloResponse` (`message = "Hello " + name`, `language` efetiva, `status = "success"`). POST com JSON malformado ou `name` ausente, vazio ou não textual retorna `400` com `{"message":"Payload inválido.","status":"error"}`, sem expor detalhes internos. Capturar exceções e nunca vazar stack trace ao cliente.

**Passo 3: converter e compilar**

Converter os fontes para Windows-1252 sem BOM e solicitar compilação de todos os fontes da feature.

**Passo 4: testar HTTP**

Sem credenciais:

```powershell
curl.exe -i http://localhost:8084/rest/api/v1/hello/mundo
```

Esperado: HTTP `401` (com `SECURITY=1`).

Com credenciais fornecidas somente ao `curl`:

```powershell
curl.exe -i -u Admin http://localhost:8084/rest/api/v1/hello/mundo?language=pt-br
curl.exe -i -u Admin -X POST -H "Content-Type: application/json" -d "{\"name\":\"mundo\"}" http://localhost:8084/rest/api/v1/hello
curl.exe -i -u Admin -X POST -H "Content-Type: application/json" -d "{}" http://localhost:8084/rest/api/v1/hello
```

Esperado: GET e POST válidos retornam `200` com `HelloResponse`; POST sem `name` retorna `400` com `ErrorResponse`. Não registrar senha ou cabeçalho Authorization.

Salvar o corpo de `GET /api/v1/openapi/core` em `artifacts/local/core-openapi.json` e executar o validador existente.

**Passo 5: commit**

```text
feat(openapi): publica demonstração de parâmetros e schemas
```

### Tarefa 9: Fechar rastreabilidade e documentação

**Arquivos:**

- Modificar: `.specs/features/openapi-parameters-schemas/spec.md`
- Modificar: `.specs/features/openapi-parameters-schemas/tasks.md`
- Modificar: `README.md`
- Criar: `docs/experiments/openapi-parameters-schemas.md`

**Passo 1: executar o gate completo**

Executar testes PROBAT/harness, contrato do núcleo, validação das fixtures `hello-core.json` e `hello-params.json`, regressões existentes e `git diff --check`.

**Passo 2: verificar completude**

Mapear PSCH-01 a PSCH-20 para evidências concretas. Registrar qualquer requisito não atendido como pendente, sem marcá-lo como concluído.

**Passo 3: atualizar documentação**

Registrar ambiente, comandos, resultados, limitações e roteiro editorial, no formato de `docs/experiments/openapi-core-model.md`. Não versionar resposta completa do ambiente, credenciais ou configuração do AppServer.

**Passo 4: commit**

```text
docs(openapi): registra parâmetros e schemas validados
```

## Gate de regressão recorrente

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-core/validate-sources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-core.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-params.json
git diff --check
```
