# Adaptador para endpoints TL++ - Design

**Especificação:** `.specs/features/openapi-tlpp-adapter/spec.md`
**Decisões:** `.specs/features/openapi-tlpp-adapter/context.md`
**Estado:** Ramo A confirmado por evidência real (compilação + HTTP) em 2026-09-25 — ver `context.md` para o resultado completo do spike (T1) e `docs/experiments/openapi-tlpp-adapter.md` para as evidências brutas.

## Arquitetura

O núcleo `OApi*` (`src/core/`) permanece inalterado e desconhece annotations, `oRest` ou reflection. O adaptador é uma camada nova, exclusivamente consumidora do núcleo, responsável por três passos:

```text
1. Localizar         2. Extrair            3. Montar
   funções alvo   →     metadados da     →    OApiPath/OApiOper/
   anotadas             annotation             OApiParam/OApiBody
   (Reflection.get      (endpoint, verbo,      (via API pública
   FunctionsBy          title, description,    já existente do
   Annotation)          responses, params)      núcleo)
```

A montagem (passo 3) reaproveita 100% da API pública já validada do núcleo — nenhuma classe `OApi*` ganha método novo neste incremento, a menos que o spike revele uma lacuna real.

## API de reflection confirmada (Ramo A)

O spike (T1, 2026-09-25) confirmou por compilação real e chamadas HTTP reais no `P12_2510` a seguinte API, disponível apenas com `#include "tlpp-core.th"` (sem `using namespace` adicional):

| Chamada | Assinatura confirmada | Retorno confirmado |
| --- | --- | --- |
| `Reflection.getFunctionsByAnnotation(cAnnotationName)` | 1 argumento | `Array` de itens `[cSourceName, cFunctionName]`; `cSourceName` é o nome do fonte em maiúsculas com extensão (`"CUSTOM.OPENAPI.HELLO.GET.TLPP"`); `cFunctionName` é o nome interno do RPO, maiúsculo e prefixado com `U_` (`"U_HELOGET"`). Enumera o RPO inteiro (297 resultados no ambiente de teste), não só os fontes do projeto — o adaptador precisa filtrar pelos fontes-alvo. |
| `Reflection.isAnnotationFunctionPresent(cSourceName, cFunctionName, cAnnotationName)` | **3 argumentos** (não 2) | `Logical` |
| `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cAnnotationName)` | **3 argumentos** (não 2) | `Json` nativo com os campos: `endpoint` (character, valor exato do atributo), `title` (character), `description` (character), `responses` (character — string JSON não parseada), `params` (character — vazia se não declarada), `requestBody` (character — vazia se não declarada), `id` (numeric), `language` (character, default `"BRA"`). |

O adaptador implementa uma função de descoberta (`Static Function` interna) que:

1. Chama `Reflection.getFunctionsByAnnotation("Get")` (e o equivalente para `Post`/`Put`/`Patch`/`Delete`) e filtra o resultado pelos `cSourceName` dos arquivos-alvo (`CUSTOM.OPENAPI.HELLO.GET.TLPP`, `CUSTOM.OPENAPI.HELLO.POST.TLPP`), descartando o restante do RPO.
2. Para cada par `[cSourceName, cFunctionName]` filtrado, chama `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cVerbo)` para obter o `Json` com `endpoint`/`title`/`description`/`responses`/`params`/`requestBody`.
3. Extrai o path a partir do único campo `endpoint` (nunca redigitado em nenhum outro lugar), convertendo `:nome` → `{nome}` — isso satisfaz ADPT-07 por construção, eliminando a classe de bug original.
4. Monta `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody` chamando exclusivamente a API pública já existente do núcleo — nenhuma classe `OApi*` muda.

Nenhuma informação adicional é exigida do desenvolvedor além da própria annotation já usada hoje: o par `endpoint`+`title`+`description` cobre P1/P2 integralmente (ADPT-04 a ADPT-09).

### Formato de `params`/`requestBody` — pendente de definição própria (não é mais um risco de descoberta)

`params` e `requestBody` já são atributos nativamente aceitos por `@Get`/`@Post` (aparecem no `Json` retornado mesmo quando não declarados, com valor default `""`), mas nenhum exemplo real observado até agora os populou — não há formato de referência a copiar. Diferente da incerteza de T1 (que era sobre uma API externa e fechada), esta é uma decisão de **design próprio**: o projeto define o formato de texto que `params`/`requestBody` devem seguir (ex.: um JSON serializado compatível com `OApiParam`/`OApiBody`) e documenta essa convenção como a "annotation complementar" pedida pelo roadmap (Fase 3, item "definir annotations complementares para schemas, respostas e exemplos"). Essa definição acontece em T3/T4, não bloqueia o início da implementação.

### Ramo B (função complementar `_DOC`) — rebaixado a fallback documentado

Descartado como mecanismo primário pela evidência do spike. Mantido apenas como alternativa registrada caso `params`/`requestBody` se mostrem insuficientes (ex.: limite de tamanho de string, dificuldade de manter JSON legível dentro de um atributo de annotation) durante T3/T4: nesse cenário, uma função irmã `_DOC` (padrão já usado oficialmente pela TOTVS) poderia complementar os dois campos sem precisar reabrir a decisão sobre o mecanismo de descoberta em si (que continua sendo `Reflection.getFunctionsByAnnotation`/`getFunctionAnnotation`).

## Componentes planejados

| Componente | Responsabilidade | Status |
| --- | --- | --- |
| Função/rotina de descoberta (nome definitivo em T2) | chamar `Reflection.getFunctionsByAnnotation`, filtrar pelos fontes-alvo, chamar `Reflection.getFunctionAnnotation` por par encontrado | a implementar (T2) |
| Parser de path (`:nome` → `{nome}`) | extrair segmentos de path e nomes de parâmetro a partir de `endpoint` | a implementar (T3) |
| Montador (`Static Function` que traduz metadados extraídos em chamadas ao núcleo) | chamar `OApiPath:new()`, `OApiOper:addParam()`, `OApiOper:setBody()` etc. | a implementar (T4/T5) |
| Função complementar `<Endpoint>_DOC()` | fallback, só se `params`/`requestBody` se mostrarem insuficientes | não planejada; documentada como alternativa |

Nomes exatos de arquivo/classe seguem o padrão `custom.openapi.*.tlpp` já usado em `src/core/`, mas o adaptador vive fora de `src/core/` (ex.: `src/adapters/` ou equivalente, a confirmar em T2 conforme convenção do projeto).

## Execução do spike (T1) — concluída em 2026-09-25

1. Criados 7 fontes de spike isolados (`examples/openapi-tlpp-adapter/custom.openapi.tlpp.spike.*.tlpp`), cada um testando uma hipótese isolada, com `Try/Catch` em cada chamada para nunca derrubar a resposta HTTP mesmo que a hipótese esteja errada.
2. Todos compilaram no `P12_2510` (`[SUCCESS]`); os avisos do Language Server (`W0008 Too few parameters`) já indicaram, antes mesmo da execução, que os nomes de método estavam certos e só a aridade (2 → 3 argumentos) estava errada.
3. Execução via HTTP real (`curl` autenticado) confirmou o mecanismo completo: enumeração, presença e leitura da annotation — ver `context.md` e `docs/experiments/openapi-tlpp-adapter.md` para os JSONs de retorno.
4. Ramo A escolhido; este `design.md` foi atualizado com a API confirmada antes de detalhar T2 em diante em `tasks.md`.

## Invariantes e validação

- O adaptador nunca escreve um path que não seja uma transformação determinística do texto do `endpoint` da annotation (substituição `:nome` → `{nome}`, sem outra manipulação).
- Conflito de path+verbo já existente no `OApiDoc` alvo é rejeitado pela validação já existente do núcleo (`OApiPath`/`OApiDoc`); o adaptador não precisa reimplementar essa regra, só não deve suprimir a exceção.
- Toda pendência de extração (annotation malformada, atributo ausente, JSON inválido em `responses`) é acumulada com contexto (arquivo, função, atributo), reaproveitando o padrão de validação acumulada já usado no núcleo — nunca lançada como exceção não tratada nem ignorada silenciosamente.
- O núcleo `OApi*` não ganha conhecimento de annotations, `oRest` ou reflection; toda essa lógica fica isolada no adaptador.

## Estratégia de testes

- T1 (spike) é validado por evidência de compilação/execução real, registrada no diário técnico — não por PROBAT formal (é investigação, não implementação).
- A partir de T2, o ciclo volta a ser RED/GREEN com PROBAT, seguindo o mesmo padrão das features anteriores (teste do adaptador processando os dois exemplos-alvo, comparando o `OApiDoc` resultante — via `JsonObject`/estrutura, não texto bruto — com o hoje montado manualmente).
- Compilação (`advpl-tlpp-compile`) e PROBAT executados a cada tarefa concluída, não só ao final — lição aplicada da sessão anterior.

## Rastreabilidade do design

| Requisitos | Decisão ou componente |
| --- | --- |
| ADPT-01 a ADPT-03 | spike (T1) — **confirmado por evidência real** em 2026-09-25 |
| ADPT-04 a ADPT-09 | função/rotina de descoberta (`Reflection.getFunctionsByAnnotation`/`getFunctionAnnotation`) + parser de path |
| ADPT-10 a ADPT-12 | parser de path (`endpoint`) + atributos `params`/`requestBody` (formato próprio a definir em T3/T4) |
| ADPT-13 a ADPT-14 | montador + validação acumulada reaproveitada do núcleo |
| ADPT-15 | diário técnico do incremento |

## Limitações deliberadas

- Reflection em métodos de classe fica fora deste incremento (decisão do usuário).
- O adaptador não lê nem escaneia texto-fonte em disco como mecanismo de descoberta — evita reintroduzir a duplicação/divergência que originou o bug.
- Tipos de retorno e parâmetros formais da função nunca são fonte de metadados (confirmado pela pesquisa: a convenção do framework é função sem parâmetros formais, retorno sempre `Logical`).
- Comentários `/*/{Protheus.doc}*/` não são annotations e não alimentam o adaptador.
