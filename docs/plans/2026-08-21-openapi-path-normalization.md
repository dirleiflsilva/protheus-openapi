# Normalização segura de paths OpenAPI - Plano de implementação

> **Para o executor:** SUB-SKILL OBRIGATÓRIA: usar `executing-plans` para implementar este plano tarefa por tarefa.

**Objetivo:** gerar, sem dependências externas, um YAML OpenAPI completo e estruturalmente válido pela consolidação exclusiva de paths duplicados sem ambiguidades.

**Arquitetura:** um script PowerShell lê UTF-8 ou CP1252, identifica a seção raiz `paths`, preserva seus blocos textuais e consolida filhos diretos compatíveis. Conflitos interrompem a execução; a saída é publicada atomicamente em UTF-8 sem BOM e o arquivo bruto permanece intocado.

**Stack:** PowerShell 7/Windows PowerShell compatível, APIs .NET de encoding e arquivos, fixtures YAML sanitizadas e Git.

---

### Tarefa 1: Consolidar operações compatíveis

**Arquivos:**

- Criar: `scripts/normalize-openapi-paths.ps1`
- Criar: `tests/openapi-normalization/run-tests.ps1`
- Criar: `tests/openapi-normalization/fixtures/unique-path.yaml`
- Criar: `tests/openapi-normalization/fixtures/merge-two-methods.yaml`
- Criar: `tests/openapi-normalization/fixtures/merge-three-methods.yaml`
- Criar: `tests/openapi-normalization/fixtures/shared-identical.yaml`

**Passo 1: escrever os testes RED**

Criar um executor sem framework externo. Cada caso deve usar um diretório temporário exclusivo, chamar o script real e verificar o conteúdo produzido. A estrutura mínima será:

```powershell
$normalizer = Join-Path $repoRoot "scripts\normalize-openapi-paths.ps1"

function Assert-True {
    param([logical]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Normalizer {
    param([string]$Fixture, [string]$Output)
    & $normalizer -InputPath $Fixture -OutputPath $Output
}
```

Asserções obrigatórias:

- `unique-path.yaml`: uma declaração do path e um `get`;
- `merge-two-methods.yaml`: uma declaração do path, um `get` e um `put`;
- `merge-three-methods.yaml`: uma declaração, `get`, `post` e `delete` na ordem;
- `shared-identical.yaml`: um único campo `parameters` e dois verbos;
- conteúdo `openapi`, `info` e `components` permanece presente.

**Passo 2: executar RED**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
```

Resultado esperado: falha informando que `scripts/normalize-openapi-paths.ps1` não existe.

**Passo 3: implementar o mínimo GREEN**

O script deve declarar:

```powershell
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [switch]$Force
)
```

Implementar funções pequenas para:

- converter chaves YAML citadas ou não citadas;
- localizar a única seção raiz `paths`;
- dividir declarações de path com linha e ordem;
- dividir filhos diretos de cada path;
- agrupar paths por comparação ordinal;
- emitir a primeira ocorrência e incorporar verbos posteriores;
- manter uma única cópia de campo compartilhado idêntico.

Nesta tarefa, leitura e gravação podem assumir UTF-8; encoding e publicação definitiva pertencem à Tarefa 3.

**Passo 4: executar GREEN**

Executar o mesmo comando e esperar todos os casos aprovados, zero falhas.

**Passo 5: verificar regressões**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
git diff --check
```

**Passo 6: commit**

```text
feat(openapi): consolida operações de paths duplicados
```

### Tarefa 2: Rejeitar conflitos e estruturas inválidas

**Arquivos:**

- Modificar: `scripts/normalize-openapi-paths.ps1`
- Modificar: `tests/openapi-normalization/run-tests.ps1`
- Criar: `tests/openapi-normalization/fixtures/duplicate-method.yaml`
- Criar: `tests/openapi-normalization/fixtures/shared-conflict.yaml`
- Criar: `tests/openapi-normalization/fixtures/without-paths.yaml`
- Criar: `tests/openapi-normalization/fixtures/duplicate-root-paths.yaml`
- Criar: `tests/openapi-normalization/fixtures/tab-indentation.yaml`

**Passo 1: escrever os testes RED**

Adicionar helper que capture sucesso, mensagem e código de saída de uma nova instância do PowerShell. Verificar:

- verbo `get` repetido falha contendo path, `get` e as duas linhas;
- `parameters` diferentes falham contendo path, campo e linhas;
- zero ou duas seções raiz `paths` falham;
- tabulação na estrutura analisada falha informando a linha;
- nenhum destino ou temporário permanece.

**Passo 2: executar RED**

Resultado esperado: pelo menos os casos de verbo, campo compartilhado e estrutura inválida falham por não serem rejeitados com os diagnósticos exigidos.

**Passo 3: implementar o mínimo GREEN**

Antes de emitir qualquer conteúdo:

- validar tabulação;
- exigir exatamente uma seção raiz `paths`;
- comparar chaves filhas por igualdade ordinal;
- tratar a lista `get`, `put`, `post`, `delete`, `options`, `head`, `patch`, `trace` como métodos;
- lançar erro para método repetido independentemente do conteúdo;
- comparar blocos normalizados de campos compartilhados e rejeitar divergências;
- incluir path, chave e linhas nas mensagens.

**Passo 4: executar GREEN e regressões**

Executar a suíte da feature, os três contratos Hello World e `git diff --check`.

**Passo 5: commit**

```text
feat(openapi): rejeita conflitos na normalização
```

### Tarefa 3: Proteger encoding e publicação

**Arquivos:**

- Modificar: `scripts/normalize-openapi-paths.ps1`
- Modificar: `tests/openapi-normalization/run-tests.ps1`

**Passo 1: escrever os testes RED**

O executor criará entradas temporárias com APIs .NET para testar UTF-8 sem BOM, UTF-8 com BOM e CP1252 contendo `Descrição` e `Ação`. Adicionar casos para:

- entrada e saída iguais;
- destino existente sem `-Force`;
- substituição com `-Force`;
- saída UTF-8 estrita sem BOM;
- preservação de acentos;
- limpeza de temporários;
- resumo contendo `Declarações`, `Paths únicos`, `Grupos consolidados` e `Operações incorporadas`.

**Passo 2: executar RED**

Resultado esperado: falhas de encoding, proteção do destino e ausência do resumo.

**Passo 3: implementar o mínimo GREEN**

- resolver caminhos absolutos e rejeitar igualdade ordinal sem diferenciar maiúsculas no Windows;
- detectar BOM UTF-8 e decodificar UTF-8 estrito;
- usar CP1252 quando os bytes não forem UTF-8 válidos;
- rejeitar destino existente sem `-Force`;
- escrever em temporário exclusivo no diretório do destino com `UTF8Encoding($false)`;
- usar `File.Replace` com backup temporário quando o destino existir e mover quando não existir;
- limpar temporário e backup em `finally`;
- emitir o resumo somente após publicação bem-sucedida.

**Passo 4: executar GREEN e regressões**

Executar a suíte da feature, os três contratos Hello World e `git diff --check`.

**Passo 5: commit**

```text
feat(openapi): protege saída do normalizador
```

### Tarefa 4: Validar o YAML real e registrar a conclusão

**Arquivos:**

- Modificar: `.specs/features/openapi-path-normalization/spec.md`
- Modificar: `.specs/features/openapi-path-normalization/tasks.md`
- Modificar: `docs/experiments/hello-world.md`
- Criar somente localmente: `artifacts/local/hello-openapi-normalized.yaml`

**Passo 1: registrar o hash do bruto**

```powershell
Get-FileHash -Algorithm SHA256 D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml
```

**Passo 2: normalizar o artefato real**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/normalize-openapi-paths.ps1 `
  -InputPath D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml `
  -OutputPath artifacts/local/hello-openapi-normalized.yaml `
  -Force
```

Resultado esperado: 232 declarações, 226 paths únicos, cinco grupos consolidados e seis operações incorporadas.

**Passo 3: validar a saída**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path artifacts/local/hello-openapi-normalized.yaml
```

Resultado esperado: OpenAPI `3.0.3` válido para o experimento e nenhuma chave de path duplicada.

**Passo 4: comprovar preservação do bruto**

Repetir `Get-FileHash` e exigir o mesmo SHA-256 do Passo 1. Confirmar também que `git status --short` não lista `artifacts/local/`.

**Passo 5: executar o gate completo**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/openapi-normalization/run-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target advpl
git diff --check
```

**Passo 6: atualizar rastreabilidade e diário**

Marcar NORM-01 a NORM-15 como verificados, registrar contagens e limitações sem incluir conteúdo do catálogo interno.

**Passo 7: commit**

```text
docs(openapi): registra validação do yaml normalizado
```

