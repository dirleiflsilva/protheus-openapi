# Núcleo do modelo OpenAPI - Plano de implementação

> **Para o executor:** SUB-SKILL OBRIGATÓRIA: usar `executing-plans` para implementar este plano tarefa por tarefa.

**Objetivo:** construir em TL++ um núcleo mínimo que modele, valide e serialize como JSON OpenAPI 3.0.3 a documentação do endpoint Hello World.

**Arquitetura:** seis classes no namespace `custom.openapi.core` separam informações, respostas, operações, paths, documento e serialização. Um endpoint de exemplo monta o modelo sem acoplar o núcleo a REST; testes PROBAT ou um harness compatível exercitam o comportamento no RPO.

**Stack:** TL++, `tlpp-core.th`, `tlpp-rest.th` somente no exemplo, `tlpp-probat.th` quando o smoke test confirmar compatibilidade, `JsonObject`, PowerShell e AppServer/RPO `P12_2510`.

---

### Tarefa 1: Preparar o ciclo TDD no RPO

**Arquivos:**

- Criar: `tests/openapi-core/custom.openapi.core.test.tlpp`
- Criar: `tests/openapi-core/validate-sources.ps1`

**Passo 1: escrever o smoke test RED**

Criar um teste com os includes `tlpp-core.th` e `tlpp-probat.th`, namespace de teste, `using namespace tlpp.probat`, `@TestFixture()` e `User Function OApiTst()`. A primeira asserção deve esperar um valor ainda inexistente no núcleo.

**Passo 2: converter e compilar**

Converter o `.tlpp` para Windows-1252 sem BOM. Perguntar ao usuário se deseja compilar com a skill `advpl-tlpp-compile`. Resultado esperado: a sintaxe do fixture é aceita; a execução falha na asserção planejada.

Se o PROBAT não descobrir `User Function`, registrar a limitação e substituir somente o executor por um endpoint de harness em `tests/openapi-core/`, preservando os mesmos casos. Não declarar `Function` nem prefixo `U_` no fonte.

**Passo 3: criar o contrato local**

O PowerShell deve rejeitar ausência de ProtheusDOC, includes fora de ordem, namespace incorreto, `tlpp.doc.generate()`, filesystem ou uso de `Function` em customização.

**Passo 4: executar GREEN do harness**

Trocar a asserção deliberada por uma asserção verdadeira e executar novamente. Esperado: um teste aprovado e zero falhas.

**Passo 5: commit**

```text
test(openapi): prepara testes do núcleo tlpp
```

### Tarefa 2: Criar `OApiInfo`

**Arquivos:**

- Criar: `src/core/custom.openapi.info.tlpp`
- Modificar: `tests/openapi-core/custom.openapi.core.test.tlpp`
- Modificar: `tests/openapi-core/validate-sources.ps1`

**Passo 1: escrever testes RED**

Testar construção com `Hello World API`, descrição e `1.0.0`; testar também título e versão vazios retornados simultaneamente por `validate()`.

**Passo 2: implementar o mínimo GREEN**

Criar a classe `OApiInfo` com dados privados, construtor, getters e `validate() as array`. Todos os métodos recebem ProtheusDOC. Locais são declarados no início e a atribuição precede o tipo.

**Passo 3: validar**

Executar contrato local, converter encoding, compilar quando autorizado e rodar os testes no RPO.

**Passo 4: commit**

```text
feat(openapi): adiciona informações do documento
```

### Tarefa 3: Criar `OApiResp`

**Arquivos:**

- Criar: `src/core/custom.openapi.response.tlpp`
- Modificar: teste e contrato do núcleo

**Passos TDD:**

1. RED: esperar código `200`, descrição e validação de campos vazios.
2. GREEN: implementar dados privados, construtor, getters e `validate()`.
3. Executar contratos, encoding, compilação e testes.
4. Commit: `feat(openapi): adiciona respostas ao modelo`.

### Tarefa 4: Criar `OApiOper`

**Arquivos:**

- Criar: `src/core/custom.openapi.operation.tlpp`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Cobrir normalização de `GET` para `get`, verbo desconhecido, inclusão de uma resposta, resposta `200` duplicada e operação sem respostas.

**Passo 2: implementar o mínimo GREEN**

Implementar `new()`, getters, `addResp()` e `validate()`. Validar antes de `AAdd`; aceitar somente `get`, `put`, `post`, `delete`, `options`, `head`, `patch` e `trace`. Usar `UserException()` para conflitos.

**Passo 3: validar e commitar**

Executar o gate da tarefa e criar `feat(openapi): adiciona operações e respostas`.

### Tarefa 5: Criar `OApiPath`

**Arquivos:**

- Criar: `src/core/custom.openapi.path.tlpp`
- Modificar: teste e contrato do núcleo

**Passos TDD:**

1. RED: path válido, path sem `/`, operação única e verbo duplicado.
2. GREEN: implementar `new()`, getters, `addOper()` e `validate()`; validar antes de alterar o array.
3. Confirmar que a primeira operação permanece após tentativa duplicada.
4. Executar contratos, encoding, compilação e testes.
5. Commit: `feat(openapi): adiciona paths ao modelo`.

### Tarefa 6: Criar `OApiDoc`

**Arquivos:**

- Criar: `src/core/custom.openapi.document.tlpp`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Testar versão fixa `3.0.3`, inclusão do path Hello World e acumulação simultânea de info inválida, ausência de paths e operação sem resposta.

**Passo 2: implementar o mínimo GREEN**

Implementar `new()`, `addPath()`, getters e `validate()`. Agregar mensagens das entidades filhas sem interromper na primeira incompletude.

**Passo 3: validar e commitar**

Executar o gate da tarefa e criar `feat(openapi): adiciona documento raiz`.

### Tarefa 7: Criar `OApiJson`

**Arquivos:**

- Criar: `src/core/custom.openapi.json.tlpp`
- Criar: `tests/openapi-core/fixtures/hello-core.json`
- Modificar: teste e contrato do núcleo

**Passo 1: escrever testes RED**

Testar recusa do documento incompleto e estrutura esperada para o documento válido. Interpretar o JSON resultante em `JsonObject` antes das asserções; não comparar texto bruto.

**Passo 2: implementar o mínimo GREEN**

Implementar `toJson(oDoc) as character`. Chamar `validate()` primeiro; havendo erros, gerar `UserException()` antes de instanciar a saída. Para documento válido, criar objetos aninhados, percorrer as coleções e retornar `ToJson()`.

**Passo 3: validação externa**

Salvar somente a fixture sanitizada e validá-la com:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-core.json
```

**Passo 4: validar e commitar**

Executar contratos, encoding, compilação e testes; criar `feat(openapi): serializa modelo como json`.

### Tarefa 8: Criar o endpoint de demonstração

**Arquivos:**

- Criar: `examples/openapi-core/custom.openapi.core.api.tlpp`
- Modificar: `tests/openapi-core/validate-sources.ps1`

**Passo 1: escrever o contrato RED**

Exigir `GET /api/v1/openapi/core`, Content-Type JSON, uso das seis classes, resposta `200`, tratamento `500` e ausência de `tlpp.doc.generate()` ou filesystem.

**Passo 2: implementar o endpoint**

Usar `using namespace custom.openapi.core`, montar o Hello World, chamar `OApiJson:toJson()` e responder pelo `oRest`. Capturar exceções sem expor detalhes internos ao cliente.

**Passo 3: converter e compilar**

Converter o fonte para Windows-1252 sem BOM e solicitar compilação de todos os fontes da feature.

**Passo 4: testar HTTP**

Sem credenciais:

```powershell
curl.exe -i http://localhost:8084/rest/api/v1/openapi/core
```

Esperado: HTTP `401`.

Com credenciais fornecidas somente ao `curl`:

```powershell
curl.exe -i -u Admin http://localhost:8084/rest/api/v1/openapi/core
```

Esperado: HTTP `200`, `application/json` e OpenAPI `3.0.3`. Não registrar senha ou cabeçalho Authorization.

Salvar o corpo em `artifacts/local/core-openapi.json` e executar o validador existente. Esperado: path `/api/v1/hello` válido.

**Passo 5: commit**

```text
feat(openapi): publica demonstração do núcleo
```

### Tarefa 9: Fechar rastreabilidade e documentação

**Arquivos:**

- Modificar: `.specs/features/openapi-core-model/spec.md`
- Modificar: `.specs/features/openapi-core-model/tasks.md`
- Modificar: `README.md`
- Criar: `docs/experiments/openapi-core-model.md`

**Passo 1: executar o gate completo**

Executar testes PROBAT ou harness aprovado, contrato do núcleo, 15 testes do normalizador, três contratos Hello World, validação da fixture e `git diff --check`.

**Passo 2: verificar completude**

Mapear CORE-01 a CORE-18 para evidências concretas. Registrar qualquer requisito não atendido como pendente, sem marcá-lo como concluído.

**Passo 3: atualizar documentação**

Registrar ambiente, comandos, resultados, limitações, decisão sobre PROBAT e roteiro editorial. Não versionar resposta completa do ambiente, credenciais ou configuração do AppServer.

**Passo 4: commit**

```text
docs(openapi): registra núcleo mínimo validado
```

## Gate de regressão recorrente

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-core/validate-sources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path tests/openapi-core/fixtures/hello-core.json
git diff --check
```
