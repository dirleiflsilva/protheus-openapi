# Normalização segura de paths OpenAPI - Tarefas

**Design:** `docs/plans/2026-08-21-openapi-path-normalization-design.md`  
**Plano:** `docs/plans/2026-08-21-openapi-path-normalization.md`  
**Estado:** aprovado

## Plano de execução

```text
T1 -> T2 -> T3 -> T4
```

As tarefas são sequenciais porque todas evoluem o mesmo script e o mesmo executor de testes. Testes PowerShell de integração são escritos e executados junto com cada comportamento.

## T1: Consolidar operações compatíveis

**O quê:** criar o executor de testes, fixtures válidas e a implementação mínima que preserva paths únicos e consolida duas ou três ocorrências com verbos distintos.  
**Onde:** `scripts/normalize-openapi-paths.ps1`, `tests/openapi-normalization/run-tests.ps1`, `tests/openapi-normalization/fixtures/`.  
**Depende de:** nenhuma.  
**Reutiliza:** conceitos de parsing em `scripts/validate-hello-openapi.ps1` e a fixture `tests/hello-world/fixtures/openapi-with-duplicate-path.yaml`.  
**Requisitos:** NORM-02, NORM-03, NORM-04, NORM-05 e NORM-06.  
**Skill:** `test-driven-development`.

**Concluída quando:**

- [ ] testes RED falham porque o normalizador ainda não existe;
- [ ] path único permanece semanticamente igual;
- [ ] duas e três ocorrências compatíveis viram um path com todos os verbos;
- [ ] campo compartilhado idêntico é emitido uma vez;
- [ ] seções fora de `paths` são preservadas;
- [ ] gate passa com `powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1`.

**Commit:** `feat(openapi): consolida operações de paths duplicados`

## T2: Rejeitar conflitos e estruturas inválidas

**O quê:** acrescentar diagnósticos para verbo repetido, campo compartilhado incompatível, seção `paths` inválida e tabulação.  
**Onde:** `scripts/normalize-openapi-paths.ps1`, `tests/openapi-normalization/run-tests.ps1`, `tests/openapi-normalization/fixtures/`.  
**Depende de:** T1.  
**Reutiliza:** analisador estrutural criado em T1.  
**Requisitos:** NORM-07, NORM-08, NORM-09 e NORM-10.  
**Skill:** `test-driven-development`.

**Concluída quando:**

- [ ] o mesmo verbo é rejeitado com path, verbo e linhas;
- [ ] campo compartilhado incompatível é rejeitado com campo, path e linhas;
- [ ] ausência ou repetição da seção raiz `paths` é rejeitada;
- [ ] tabulação na estrutura analisada é rejeitada;
- [ ] toda falha retorna código diferente de zero e não deixa destino parcial;
- [ ] gate completo permanece verde.

**Commit:** `feat(openapi): rejeita conflitos na normalização`

## T3: Proteger encoding e publicação da saída

**O quê:** implementar detecção UTF-8/CP1252, proteção de caminhos, `-Force`, UTF-8 sem BOM, gravação atômica e resumo.  
**Onde:** `scripts/normalize-openapi-paths.ps1`, `tests/openapi-normalization/run-tests.ps1`.  
**Depende de:** T2.  
**Reutiliza:** padrão de temporário e substituição de `scripts/extract-hello-openapi.ps1`.  
**Requisitos:** NORM-01, NORM-10, NORM-11, NORM-12, NORM-13, NORM-14 e NORM-15.  
**Skill:** `test-driven-development`.

**Concluída quando:**

- [ ] entradas UTF-8 e CP1252 preservam caracteres acentuados;
- [ ] entrada e saída iguais são rejeitadas;
- [ ] destino existente exige `-Force`;
- [ ] substituição válida é atômica;
- [ ] saída não contém BOM e é UTF-8 estrito;
- [ ] resumo contém os quatro contadores definidos;
- [ ] nenhum temporário permanece após sucesso ou falha;
- [ ] gate completo permanece verde.

**Commit:** `feat(openapi): protege saída do normalizador`

## T4: Validar o YAML real e documentar o resultado

**O quê:** executar o normalizador sobre o artefato local, validar as contagens e registrar o resultado sem versionar os YAMLs do ambiente.  
**Onde:** `.specs/features/openapi-path-normalization/spec.md`, `.specs/features/openapi-path-normalization/tasks.md`, `docs/experiments/hello-world.md`.  
**Depende de:** T3.  
**Reutiliza:** `scripts/validate-hello-openapi.ps1` e `D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml`.  
**Requisitos:** NORM-01 a NORM-15.  
**Skill:** `verification-before-completion`.

**Concluída quando:**

- [ ] o arquivo bruto mantém hash e data inalterados;
- [ ] a saída fica em `artifacts/local/` e não é rastreada;
- [ ] 232 declarações resultam em 226 paths únicos;
- [ ] cinco grupos são consolidados sem conflito;
- [ ] não restam chaves de path duplicadas;
- [ ] `validate-hello-openapi.ps1` aceita o YAML normalizado;
- [ ] todos os testes da feature e os contratos Hello World passam;
- [ ] rastreabilidade NORM-01 a NORM-15 é marcada como verificada.

**Commit:** `docs(openapi): registra validação do yaml normalizado`

## Validações pré-aprovação

- **Granularidade:** cada tarefa entrega um comportamento independente e verificável.
- **Dependências:** o diagrama `T1 -> T2 -> T3 -> T4` corresponde aos campos `Depende de`.
- **Testes co-localizados:** T1, T2 e T3 incluem seus próprios testes PowerShell; T4 executa a suíte completa e a validação operacional.
- **Paralelismo:** não recomendado devido ao compartilhamento dos mesmos arquivos.

