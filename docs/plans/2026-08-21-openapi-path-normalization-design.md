# Normalização segura de paths OpenAPI - Design

**Especificação:** `.specs/features/openapi-path-normalization/spec.md`  
**Decisões:** `.specs/features/openapi-path-normalization/context.md`  
**Estado:** aprovado em 2026-08-21

## Abordagens avaliadas

| Abordagem | Avaliação |
| --- | --- |
| Normalizador PowerShell sem dependências | escolhida; permite validar rapidamente as regras sobre o artefato real. |
| Implementação direta em TL++ | adiada; aumentaria o custo antes de o algoritmo estar comprovado. |
| Extração somente dos endpoints experimentais | rejeitada; não produz um documento completo válido. |
| Alteração do TLPPCore | rejeitada; o componente não está sob controle deste projeto. |

## Arquitetura

O script `scripts/normalize-openapi-paths.ps1` receberá `-InputPath`, `-OutputPath` e o switch opcional `-Force`. O processamento será local, determinístico e sem dependências externas.

```text
YAML bruto -> detectar encoding -> mapear blocos de paths
           -> validar conflitos -> consolidar grupos seguros
           -> gravar temporário UTF-8 -> publicar atomicamente
           -> validar ausência de duplicidades
```

O documento bruto será somente leitura. O resultado real será escrito em `artifacts/local/`, diretório ignorado pelo Git. Apenas código, documentação e fixtures sanitizadas serão versionados.

## Componentes

| Componente | Responsabilidade |
| --- | --- |
| `scripts/normalize-openapi-paths.ps1` | validar argumentos, ler encoding, analisar `paths`, consolidar e publicar a saída. |
| `tests/openapi-normalization/run-tests.ps1` | executar os cenários válidos e inválidos sem framework externo. |
| `tests/openapi-normalization/fixtures/` | armazenar entradas e resultados mínimos sem dados do ambiente. |
| `scripts/validate-hello-openapi.ps1` | validar o documento normalizado quando ele contiver o endpoint experimental TL++. |

## Leitura e modelo estrutural

A leitura tentará UTF-8 estrito após tratar BOM. Se os bytes não formarem UTF-8 válido, o conteúdo será interpretado como CP1252. Conteúdo ASCII é equivalente nas duas codificações.

O analisador localizará exatamente uma chave raiz `paths:` e dividirá seus filhos diretos em blocos. Cada bloco guardará a chave, a linha inicial, a ordem e seus filhos diretos. Os filhos serão classificados como operações HTTP ou campos compartilhados. O script preservará as seções anteriores e posteriores a `paths`.

## Consolidação

Paths serão agrupados por igualdade ordinal. A posição da primeira ocorrência será preservada. Operações encontradas nas ocorrências posteriores serão acrescentadas na ordem original.

- Operações HTTP diferentes serão combinadas.
- A repetição do mesmo verbo sempre será conflito.
- Campos compartilhados com blocos equivalentes serão emitidos uma vez.
- Campos compartilhados diferentes serão conflito.
- Nenhum conteúdo será escolhido ou descartado para contornar ambiguidade.

Comentários e linhas em branco pertencentes aos blocos serão preservados sempre que isso não alterar a estrutura. A saída poderá normalizar o encoding, mas não deverá alterar valores escalares ou o conteúdo das operações.

## Gravação e recuperação

Entrada e saída deverão resolver para caminhos distintos. Um destino existente exigirá `-Force`. O conteúdo completo será escrito primeiro em arquivo temporário UTF-8 sem BOM no diretório do destino. Somente após todas as validações o temporário será movido ou substituirá atomicamente o destino. O bloco de limpeza removerá exclusivamente os temporários criados pela execução.

## Diagnósticos

Falhas retornarão código diferente de zero e informarão o path, o campo ou verbo e as linhas de origem quando aplicável. O sucesso informará:

- declarações de path lidas;
- quantidade de paths únicos;
- grupos consolidados;
- operações incorporadas.

## Estratégia de testes

As fixtures cobrirão path único, duas e três ocorrências compatíveis, verbo repetido, campo compartilhado idêntico, campo compartilhado conflitante, ausência ou duplicidade da seção `paths`, tabulação, CP1252, UTF-8, caminhos iguais, proteção do destino, `-Force`, limpeza após falha e preservação das seções externas.

O teste operacional usará o YAML real apenas localmente. O aceite exige 232 declarações de entrada, 226 paths únicos de saída, cinco grupos consolidados, nenhuma duplicidade restante e aprovação do validador estrutural.

## Rastreabilidade do design

| Requisitos | Componente ou decisão |
| --- | --- |
| NORM-01 | detecção de UTF-8 estrito com fallback CP1252. |
| NORM-02 a NORM-06 | analisador estrutural e consolidação conservadora. |
| NORM-07 e NORM-08 | detector de conflitos com path, chave e linhas. |
| NORM-09 | validação da seção `paths` e da indentação. |
| NORM-10 a NORM-14 | publicação atômica, proteção da entrada e limpeza. |
| NORM-15 | resumo estruturado da execução. |

## Limites deliberados

- O script não cria documentação para `WSRESTFUL`.
- O script não valida toda a especificação OpenAPI.
- O script não resolve referências, schemas ou conflitos semânticos internos às operações.
- A eventual implementação em TL++ será uma feature posterior, baseada no comportamento comprovado nesta etapa.
