# Adaptador para endpoints TL++ - Decisões

**Data:** 2026-09-25
**Estado:** aprovado

## Decisões do usuário

| Tema | Decisão |
| --- | --- |
| Sequenciamento diante do risco | spike de verificação empírica primeiro (compilar e rodar no `P12_2510`); só fechar o design definitivo do adaptador depois do resultado real. |
| Profundidade do escopo | somente `User Function` anotadas neste incremento; reflection em métodos de classe fica documentada como limitação/próximo passo. |
| Nome da feature | `openapi-tlpp-adapter`. |
| Exemplos-alvo da reflection | `examples/openapi-parameters-schemas/custom.openapi.hello.get.tlpp` e `custom.openapi.hello.post.tlpp` (já anotados e validados via HTTP real na feature anterior). |
| Núcleo `OApi*` | não é alterado neste incremento, a menos que uma lacuna real apareça durante o trabalho (mesma regra geral do projeto). |
| Adaptador AdvPL/`WSRESTFUL` | fora de escopo — pertence à Fase 4 do roadmap. |

## Achados da pesquisa que motivam o spike (2026-09-25)

- Não existe nenhum arquivo `tlpp-core.th`/`tlpp-rest.th`, nem o motor do REST 2.0, nas árvores padrão locais (`P12.1.2510-202505\Master\Fontes`, `LIB912`) — só código-cliente que *usa* `@Get`/`@Post`, nunca quem os processa.
- A API de reflection candidata (`Reflection.getFunctionsByAnnotation`, `Reflection.getFunctionAnnotation`, classes `Attribute`/`Method`) está descrita no TDN (`Reflection e Annotation`, `Classe Attribute`, `Classe Method`), mas o acesso direto retornou HTTP 403 tanto para o agente quanto para o subagente de pesquisa; a única confirmação veio de um proxy leitor de página, sem citação de código-fonte real compilável. **Tratar como hipótese, não como fato.**
- **Atualização (2026-09-25, pós-pergunta ao usuário):** uma segunda busca nas fontes padrão locais (`P12.1.2510-202505\Master\Fontes`) encontrou 3 arquivos reais de produção usando `Reflection.*` de fato: `Livros Fiscais\Arquivos\Estadual\ScancRef\backoffice.fiscal.arquivos.utils.tlpp`, `...scancref.model.tlpp` e `Livros Fiscais\Arquivos\Municipal\...nfsesorocaba.domain.tlpp`. Isso **confirma por código real** a sintaxe de chamada `Reflection.<Metodo>(args)` (sem instanciar, só com `#include 'tlpp-core.th'`) e os métodos `Reflection.getAttributesByAnnotation(oObj, cAnnotationName)`, `Reflection.isAnnotationDataPresent(oObj, cAttributeName, cAnnotationName)`, `Reflection.getDataAnnotation(oObj, cAttributeName, cAnnotationName)` e `Reflection.getDataValue(oObj, cAttributeName)` — todos operando sobre **anotações de dado/propriedade de objeto** (`Data ... as Character` decorado com `@NomeDaAnnotation(...)`), declaradas com a sintaxe `@annotation Nome \n prop as tipo default valor \n @end` (confirmada em `nfsesorocaba.domain.tlpp:9-15` com `@annotation MagneticFileField`).
- **O que continua NÃO confirmado por código real:** os equivalentes para **função** (`Reflection.getFunctionsByAnnotation`, `Reflection.getFunctionAnnotation`, `Reflection.isAnnotationFunctionPresent`) — nenhuma ocorrência encontrada em nenhum arquivo real. É exatamente essa lacuna que o spike (T1) precisa fechar: a convenção de chamada (`Reflection.<Metodo>(...)`) está provada; falta confirmar se existe um método análogo para funções anotadas com `@Get`/`@Post`, e com qual assinatura exata.
- Também confirmado por código real (`backoffice.ba.insights.insightmessage.tlpp:127-136`): sintaxe de tratamento de exceção em TLPP é `Try / Catch oException / EndTry`, com `oException:genCode` e `oException:description` disponíveis no objeto capturado.
- Está confirmado por código real (fontes de produção + repositório oficial `totvs/tlpp-sample-rest-documentation`): a sintaxe exata `@Get(endpoint="...", title="...", description="...", responses='...')`, o uso de `:nome` para path params, e que **somente o atributo `endpoint` tem efeito funcional** — os demais (`title`, `description`, `responses`) são puramente informativos, não validados pelo framework. Essa assimetria é a causa raiz da classe de bug da sessão anterior (path errado no documento OpenAPI) e é o motivo principal de existir este adaptador.
- Funções/métodos anotados **não recebem parâmetros formais** — toda entrada (path/query/header/body) só existe via o objeto global `oRest`. Logo, parâmetros nunca podem ser inferidos da assinatura da função, só do texto da própria annotation (ou de uma função `_DOC`/`RestDoc` complementar).
- Existe uma issue pública (`totvs/tlpp-sample-rest-documentation#6`) documentando que a própria ferramenta oficial de geração de OpenAPI da TOTVS tem bugs de path params em rotas nativas — evidência de que a introspecção automática de path params tem limites reais mesmo na referência oficial.

## Resultado do spike (2026-09-25) — Ramo A confirmado

O spike (T1) foi executado por completo: compilação real no `P12_2510` (`[SUCCESS]` para todos os fontes) e verificação HTTP real via `curl` autenticado. Resultado:

- `Reflection.getFunctionsByAnnotation("Get")` **funciona** e enumera todas as funções anotadas com `@Get` em todo o RPO do ambiente (297 resultados no momento do teste, crescendo a cada novo `@Get` compilado). Cada item é um `Array` de 2 posições: `[cSourceName, cFunctionName]`, ambos em maiúsculas — ex.: `["CUSTOM.OPENAPI.HELLO.GET.TLPP", "U_HELOGET"]` (nome do fonte com extensão; nome da função com o prefixo interno `U_` do RPO).
- `Reflection.isAnnotationFunctionPresent(cSourceName, cFunctionName, cAnnotationName)` **funciona** com assinatura de **3 argumentos** (não 2, como a analogia inicial com a variante de dado sugeria) — confirmado tanto pelo Language Server (aviso `W0008 Too few parameters` na tentativa de 2 argumentos) quanto por execução real (`"present":true` para `HeloGet`/`Get`).
- `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cAnnotationName)` **funciona**, também com 3 argumentos, e devolve um **`Json` nativo** (não um objeto `Attribute`/`Method` como o TDN sugeria) com os campos: `endpoint`, `title`, `description`, `responses` (string contendo o JSON declarado no atributo, não parseado), `params` (string, vazia no exemplo testado), `requestBody` (string, vazia no exemplo testado), `id` (numeric) e `language` (character, `"BRA"` por default).
- **Achado não antecipado:** `params` e `requestBody` já são atributos nativamente suportados por `@Get`/`@Post` (aparecem no JSON mesmo sem terem sido declarados no `custom.openapi.hello.get.tlpp`, com valor default `""`). Isso significa que o adaptador pode conseguir parâmetros de query/header e request body **sem precisar de uma função complementar `_DOC`** (Ramo B), bastando descobrir o formato de texto esperado dentro dessas duas strings — isso fica para T2/T3, não bloqueia mais o início da implementação.
- **Decisão:** Ramo A (design.md) confirmado como arquitetura definitiva. Ramo B (função complementar `_DOC`) é descartado como mecanismo primário; passa a ser só uma alternativa de fallback documentada, caso `params`/`requestBody` se revelem insuficientes durante T3/T4.
- Evidência completa (chamadas HTTP, JSONs de retorno) registrada em `docs/experiments/openapi-tlpp-adapter.md`.

## Discrição do agente

- Local e nome exato do fonte de spike (T1), desde que sob `examples/openapi-tlpp-adapter/` ou `tests/` conforme a convenção do projeto.
- Nomes exatos das classes/funções do adaptador, respeitando os padrões já usados em `src/core/` (prefixo `OApi`, um arquivo por classe, `custom.openapi.*.tlpp`).
- Organização interna da representação intermediária entre a leitura da annotation e a montagem das instâncias `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody`.
- Mensagens exatas de diagnóstico e de limitação documentada, mantendo contexto, estabilidade e segurança.

## Itens adiados

- Reflection em métodos de classes (`public Method` anotado) — só funções (`User Function`) neste incremento.
- Adaptador `WSRESTFUL`/AdvPL (Fase 4).
- Annotations complementares avançadas (schemas de exemplo, respostas múltiplas, segurança) além do necessário para os dois exemplos-alvo.
- Descoberta em escala (múltiplos arquivos/diretórios) — este incremento cobre só os dois exemplos-alvo.
- Rotas dinâmicas registradas via `sLoadURNs`/`jEndpoints` (registro sem annotation) — fora do padrão `@Get`/`@Post` estático que é o alvo desta fase.
