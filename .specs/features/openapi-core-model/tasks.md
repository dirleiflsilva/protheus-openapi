# Núcleo do modelo OpenAPI - Tarefas

**Design:** `.specs/features/openapi-core-model/design.md`
**Plano:** `docs/plans/2026-08-21-openapi-core-model.md`
**Estado:** concluído

## Plano de execução

```text
T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> T7 -> T8 -> T9
```

As tarefas são sequenciais porque cada entidade adiciona um nível do modelo e evolui o mesmo conjunto de testes. Cada tarefa de fonte inclui teste RED, implementação mínima, conversão Windows-1252, compilação quando autorizada e gate de regressão.

## T1: Validar o harness de testes TL++

**O quê:** criar o teste mínimo do PROBAT com `User Function` e o validador local de contratos.
**Onde:** `tests/openapi-core/custom.openapi.core.test.tlpp`, `tests/openapi-core/validate-sources.ps1`.
**Depende de:** nenhuma.
**Reutiliza:** `tlpp-probat.th`, amostra oficial TOTVS e padrão dos testes PowerShell existentes.
**Requisitos:** suporte de verificação para CORE-01 a CORE-17.
**Skills:** `test-driven-development`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] `@TestFixture()` compila sobre `User Function` sem declaração explícita de `U_`;
- [x] pelo menos uma asserção deliberadamente falha e depois passa;
- [x] o PROBAT descobriu a `User Function`; não foi necessário criar um harness REST alternativo;
- [x] o contrato PowerShell identifica includes, namespace e documentação obrigatórios.

**Commit:** `test(openapi): prepara testes do núcleo tlpp`

## T2: Implementar informações da API

**O quê:** criar `OApiInfo` com título, descrição, versão e validação acumulada.
**Onde:** `src/core/custom.openapi.info.tlpp` e teste do núcleo.
**Depende de:** T1.
**Reutiliza:** sintaxe de classe, namespace e ProtheusDOC validada nas referências locais.
**Requisitos:** CORE-02 e parte de CORE-11.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] os valores informados são recuperados sem alteração;
- [x] título e versão vazios aparecem juntos no array de validação;
- [x] fonte contém ProtheusDOC completo e está em Windows-1252 sem BOM;
- [x] testes e compilação passam.

**Commit:** `feat(openapi): adiciona informações do documento`

## T3: Implementar respostas

**O quê:** criar `OApiResp` para código e descrição de resposta.
**Onde:** `src/core/custom.openapi.response.tlpp` e teste do núcleo.
**Depende de:** T2.
**Reutiliza:** padrão de entidade estabelecido por `OApiInfo`.
**Requisitos:** CORE-04.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] código `200` e descrição são preservados;
- [x] valores obrigatórios vazios são diagnosticados;
- [x] testes, encoding e compilação passam.

**Commit:** `feat(openapi): adiciona respostas ao modelo`

## T4: Implementar operações

**O quê:** criar `OApiOper` com normalização de verbo e coleção de respostas únicas.
**Onde:** `src/core/custom.openapi.operation.tlpp` e teste do núcleo.
**Depende de:** T3.
**Reutiliza:** `OApiResp`.
**Requisitos:** CORE-03, CORE-04, CORE-07, CORE-09, CORE-10 e CORE-12.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] verbo suportado é armazenado em minúsculas;
- [x] verbo desconhecido falha imediatamente;
- [x] resposta duplicada falha sem substituir a original;
- [x] operação sem resposta gera pendência acumulada;
- [x] testes, encoding e compilação passam.

**Commit:** `feat(openapi): adiciona operações e respostas`

## T5: Implementar paths

**O quê:** criar `OApiPath` com path válido e operações únicas por verbo.
**Onde:** `src/core/custom.openapi.path.tlpp` e teste do núcleo.
**Depende de:** T4.
**Reutiliza:** `OApiOper`.
**Requisitos:** CORE-03, CORE-06, CORE-08 e CORE-10.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] path iniciado por `/` aceita uma operação;
- [x] path inválido falha antes de alterar o objeto;
- [x] verbo repetido no mesmo path falha sem substituir a primeira operação;
- [x] testes, encoding e compilação passam.

**Commit:** `feat(openapi): adiciona paths ao modelo`

## T6: Implementar o documento raiz

**O quê:** criar `OApiDoc` com versão 3.0.3, info, paths e validação acumulada.
**Onde:** `src/core/custom.openapi.document.tlpp` e teste do núcleo.
**Depende de:** T5.
**Reutiliza:** `OApiInfo` e `OApiPath`.
**Requisitos:** CORE-01, CORE-02, CORE-05, CORE-11 e CORE-12.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] versão OpenAPI é sempre `3.0.3`;
- [x] Hello World pode ser representado integralmente;
- [x] validação relata simultaneamente info e paths ausentes;
- [x] testes, encoding e compilação passam.

**Commit:** `feat(openapi): adiciona documento raiz`

## T7: Implementar o serializador JSON

**O quê:** criar `OApiJson` que rejeita modelo incompleto e serializa o documento válido.
**Onde:** `src/core/custom.openapi.json.tlpp`, teste do núcleo e fixture JSON esperada.
**Depende de:** T6.
**Reutiliza:** `JsonObject():New()`, `ToJson()` e `scripts/validate-hello-openapi.ps1`.
**Requisitos:** CORE-13, CORE-14 e CORE-15.
**Skills:** `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] documento incompleto gera erro antes de criar saída;
- [x] JSON válido contém info, path, get e resposta `200`;
- [x] teste compara estrutura, não ordem textual;
- [x] testes, encoding e compilação passam.

**Commit:** `feat(openapi): serializa modelo como json`

## T8: Publicar o endpoint de demonstração

**O quê:** criar `GET /api/v1/openapi/core` como cliente do núcleo.
**Onde:** `examples/openapi-core/custom.openapi.core.api.tlpp` e contratos locais.
**Depende de:** T7.
**Reutiliza:** padrão de `examples/hello-world/hello-api.tlpp`.
**Requisitos:** CORE-05, CORE-16, CORE-17 e CORE-18.
**Skills:** `tlpp-rest-endpoint-generator`, `test-driven-development`, `documentation-writer`, `utf8-to-cp1252-conversion`, `advpl-tlpp-compile`.

**Concluída quando:**

- [x] endpoint não usa `tlpp.doc.generate()` nem filesystem;
- [x] chamada sem autenticação retorna `401` pelo AppServer;
- [x] chamada autenticada retorna `200`, `application/json` e o documento esperado;
- [x] JSON capturado passa no validador OpenAPI do projeto.

**Commit:** `feat(openapi): publica demonstração do núcleo`

## T9: Registrar evidências e atualizar o roadmap

**O quê:** documentar resultados, decisões, limitações, comandos e roteiro editorial.
**Onde:** README, documentação da feature e diário técnico correspondente.
**Depende de:** T8.
**Reutiliza:** formato de `docs/experiments/hello-world.md`.
**Requisitos:** rastreabilidade de CORE-01 a CORE-18.
**Skills:** `verification-before-completion`.

**Concluída quando:**

- [x] cada requisito está marcado com evidência verificável;
- [x] versão do ambiente e resultado do PROBAT/harness estão registrados;
- [x] README indica o núcleo mínimo como concluído;
- [x] nenhum artefato sensível ou credencial é versionado;
- [x] gate completo passa.

**Commit:** `docs(openapi): registra núcleo mínimo validado`

## Validações pré-aprovação

- **Granularidade:** cada tarefa entrega uma classe, harness, endpoint ou documentação.
- **Dependências:** o diagrama linear corresponde aos campos `Depende de`.
- **Testes co-localizados:** toda tarefa de fonte evolui o teste do núcleo e exige compilação após encoding.
- **Cobertura:** CORE-01 a CORE-18 estão associados a pelo menos uma tarefa.
