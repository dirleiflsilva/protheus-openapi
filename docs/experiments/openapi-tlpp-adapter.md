# Adaptador para endpoints TL++ — spike de reflection

## Ambiente alvo

| Componente | Versão alvo |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | P12_2510 (`http://localhost:8084/rest`) |

## Contexto

A montagem do documento OpenAPI é hoje 100% manual (`examples/openapi-core/custom.openapi.core.api.tlpp`), o que já causou um bug real de path divergente (2026-09-24, ver `docs/experiments/openapi-parameters-schemas.md`). A Fase 3 do roadmap propõe um adaptador que descubra endpoints `@Get`/`@Post`/etc. via reflection e monte as instâncias `OApi*` automaticamente. Antes de desenhar esse adaptador, era preciso confirmar se a API de reflection candidata (`Reflection.getFunctionsByAnnotation`, `Reflection.getFunctionAnnotation`, descritas no TDN) existe de fato nesta versão — nenhuma ocorrência foi encontrada em nenhuma árvore padrão local (`P12.1.2510-202505\Master\Fontes`, `LIB912`) usando essas variantes especificamente para função (só para dado/propriedade de objeto).

## Spike — sequência de evidências (2026-09-25)

### 1. Controle — `Reflection.getAttributesByAnnotation`

Reaplica o padrão já confirmado em código real de produção (`backoffice.fiscal.arquivos.utils.tlpp`) sobre uma annotation e classe descartáveis, para provar que o namespace `Reflection` resolve neste AppServer antes de testar as variantes de função.

```
GET /api/v1/openapi/spike/control
→ {"experiment":"Reflection.getAttributesByAnnotation(oObj, 'TlaSpike')","success":true,"resultCount":1}
```

### 2. Enumeração por annotation — `Reflection.getFunctionsByAnnotation`

```
GET /api/v1/openapi/spike/enum
→ {"experiment":"Reflection.getFunctionsByAnnotation('Get')","success":true,"resultCount":295}
```

Funciona com 1 argumento (nome da annotation) e enumera **todo o RPO do ambiente**, não só os fontes do projeto — o `resultCount` cresceu de 295 para 297 ao longo da sessão, à medida que novos fontes de spike com `@Get` eram compilados, confirmando que a enumeração reflete o RPO compilado em tempo real.

### 3. Layout do retorno — `custom.openapi.tlpp.spike.inspect2.tlpp`

Cada item retornado é um `Array` de 2 posições:

```
GET /api/v1/openapi/spike/inspect2
→ {"success":true,"resultCount":297,"items":[
    {"itemValType":"A","itemLen":2,"positions":[
      {"position":1,"valType":"C","value":"CUSTOM.OPENAPI.CORE.API.TLPP"},
      {"position":2,"valType":"C","value":"U_OAPICORE"}]},
    {"itemValType":"A","itemLen":2,"positions":[
      {"position":1,"valType":"C","value":"CUSTOM.OPENAPI.HELLO.GET.TLPP"},
      {"position":2,"valType":"C","value":"U_HELOGET"}]},
    ...
]}
```

`cSourceName` (posição 1) é o nome do fonte em maiúsculas com extensão; `cFunctionName` (posição 2) é o nome interno do RPO, maiúsculo e prefixado com `U_` (o prefixo que o compilador adiciona a toda `User Function`).

### 4. Aridade de `isAnnotationFunctionPresent`/`getFunctionAnnotation`

Uma primeira tentativa com 2 argumentos (`cFuncName`, `cAnnotationName`, por analogia com a variante de dado) gerou aviso do Language Server **antes mesmo de compilar no servidor**:

```
W0008 Too few parameters calling Reflection.isAnnotationFunctionPresent
W0008 Too few parameters calling Reflection.getFunctionAnnotation
```

Isso já confirmou que as duas funções existem (senão seria "method not found"), só com aridade maior. Com 3 argumentos e `cSourceName`/`cFunctionName` ainda como palpite (`"HeloGet"`, sem o prefixo `U_` correto), a chamada passou a compilar sem aviso, mas retornou `false`/vazio em runtime (palpite de `cSourceName` errado):

```
GET /api/v1/openapi/spike/attr2
→ {"experiments":[
    {"experiment":"...('custom.openapi.hello.get', 'HeloGet', 'Get')","success":true,"result":false},
    {"experiment":"...('HeloGet', 'HeloGet', 'Get')","success":true,"result":false}]}
```

### 5. Confirmação final — valores reais de `cSourceName`/`cFunctionName`

Reusando exatamente os valores descobertos no passo 3 (`"CUSTOM.OPENAPI.HELLO.GET.TLPP"`, `"U_HELOGET"`):

```
GET /api/v1/openapi/spike/inspect3
→ {
  "presentSuccess": true,
  "present": true,
  "annotationSuccess": true,
  "annotationValType": "J",
  "annotationJson": {
    "endpoint": "/api/v1/hello/:name",
    "title": "Consulta saudação",
    "description": "Retorna uma saudação personalizada usando o parâmetro de path name e o parâmetro opcional de query language.",
    "responses": "[{\"statusCode\":200,\"description\":\"Saudação retornada com sucesso.\"}]",
    "params": "",
    "requestBody": "",
    "id": 0,
    "language": "BRA"
  }
}
```

## Conclusão

| Chamada | Assinatura confirmada | Retorno |
| --- | --- | --- |
| `Reflection.getFunctionsByAnnotation(cAnnotationName)` | 1 argumento | `Array` de `[cSourceName, cFunctionName]` (maiúsculas; função prefixada `U_`) |
| `Reflection.isAnnotationFunctionPresent(cSourceName, cFunctionName, cAnnotationName)` | 3 argumentos | `Logical` |
| `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cAnnotationName)` | 3 argumentos | `Json` nativo: `endpoint`, `title`, `description`, `responses` (string), `params` (string, default `""`), `requestBody` (string, default `""`), `id` (numeric), `language` (character, default `"BRA"`) |

O mecanismo de reflection existe e funciona como o TDN descrevia na essência (nomes de método corretos), mas divergia em dois pontos não documentados encontrados apenas empiricamente: a aridade real (3 argumentos, não 2) e o formato de `cSourceName`/`cFunctionName` (maiúsculas, função prefixada `U_`). O achado não antecipado — `params`/`requestBody` já nativamente suportados pela annotation — abre caminho para o adaptador não precisar de nenhuma função complementar `_DOC` neste incremento.

**Decisão:** Ramo A (design.md) confirmado como arquitetura definitiva do adaptador. Ver `.specs/features/openapi-tlpp-adapter/` para spec/design/tasks atualizados com a API real.

## T2 — função de descoberta (2026-09-25)

Implementada a classe `OApiAdpDsc` (`src/adapters/custom.openapi.adapter.discovery.tlpp`, namespace `custom.openapi.adapter.tlpp`), com o método `discover(cVerb, aSources)` que encapsula a sequência confirmada no spike: `Reflection.getFunctionsByAnnotation(cVerb)` → filtro por `cSourceName` → `Reflection.getFunctionAnnotation(cSourceName, cFunctionName, cVerb)` por par filtrado.

**Contrato estático:** `tests/openapi-tlpp-adapter/validate-sources.py` (Python — mesmo padrão dos gates das features anteriores) — `Contrato do adaptador TL++ válido.`

**Compilação:** os 2 fontes (`src/adapters/custom.openapi.adapter.discovery.tlpp`, `tests/openapi-tlpp-adapter/custom.openapi.tlpp.adapter.test.tlpp`) compilaram `[SUCCESS]` no `P12_2510`.

**PROBAT:** fixture `OApiAdpTst` (4 asserções) executado via `tlpp.probat.run` — log sem `THREAD ERROR` nem `>> assert << - result: ERROR`, mesmo critério de sucesso já estabelecido em `docs/experiments/openapi-parameters-schemas.md`. Casos cobertos:

1. `discover("Get", {HELLO.GET, HELLO.POST})` → 1 resultado (`HeloGet`/`U_HELOGET`/`endpoint="/api/v1/hello/:name"`/`title` preservado).
2. `discover("Post", {HELLO.GET, HELLO.POST})` → 1 resultado (`HeloPost`/`U_HELOPOST`/`endpoint="/api/v1/hello"`).
3. `discover("Get", {fonte inexistente})` → 0 resultados, sem erro.
4. `discover("Delete", {HELLO.GET, HELLO.POST})` → 0 resultados, sem erro (nenhum dos dois tem `@Delete`).

**Achado colateral:** o script `convert-encoding.bat` da skill `utf8-to-cp1252-conversion` está salvo em UTF-8 com acentos; o `cmd.exe` (codepage do sistema, não Unicode) corrompe o parsing do próprio `.bat` assim que encontra um caractere acentuado, e o script nunca converte nada de fato nesta máquina — silenciosamente, sem erro visível. Contornado nesta sessão convertendo o único arquivo com acentos (`custom.openapi.tlpp.adapter.test.tlpp`) via `python -c` direto (leitura UTF-8, escrita CP1252). Fica registrado como pendência de correção da skill (fora do escopo desta feature).

## T3 — parser de path (2026-09-25)

Implementada a classe `OApiAdpPath` (`src/adapters/custom.openapi.adapter.path.tlpp`), com `toTemplate(cEndpoint)` (converte `:nome` → `{nome}`) e `toParams(cEndpoint)` (gera um `OApiParam` de path obrigatório, schema `string`, por segmento `:nome`, na ordem do texto). Ambos os métodos operam por parsing de caracteres (`SubStr`/`Len`), sem depender de nenhuma API não confirmada.

**Contrato estático:** `tests/openapi-tlpp-adapter/validate-sources.py` estendido com `check_path_class()` — `Contrato do adaptador TL++ válido.`

**Compilação:** os 2 fontes (`src/adapters/custom.openapi.adapter.path.tlpp`, teste atualizado) compilaram `[SUCCESS]` no `P12_2510`.

**PROBAT:** fixture `OApiAdpTst` ampliado para 10 asserções (as 4 de T2 + 6 novas) — sem `THREAD ERROR`. As novas asserções usam o `endpoint` **descoberto por `OApiAdpDsc`** (não um literal redigitado no teste), fechando o ciclo completo: reflection → template/parâmetro, sem nenhum ponto intermediário onde o path possa divergir — a mesma classe de bug da sessão anterior (path registrado sob a chave errada) fica estruturalmente impossível neste fluxo.

**Achado colateral (encoding):** ao usar o Edit tool para adicionar as novas asserções ao fixture já convertido para CP1252, o texto acentuado existente (`"Consulta saudação"`) foi silenciosamente corrompido para caracteres de substituição Unicode (`U+FFFD`) — o Edit tool releu o arquivo assumindo UTF-8, encontrou os bytes CP1252 de "ç"/"ã" como inválidos, e os substituiu irreversivelmente ao regravar. Confirma na prática a lição já registrada em memória (`encoding_reconvert_before_edit`): nunca editar diretamente um `.tlpp` já convertido para CP1252 quando o texto tem acentos — o trecho precisou ser retdigitado manualmente antes da conversão final. Também confirmado nesta sessão: o script `convert-encoding.bat` da skill está quebrado (ver nota em T2) — a conversão final de todo o incremento foi feita via `python -c` direto.

## T4 — formato de params/requestBody (2026-09-25)

Definido o formato (decisão de design do próprio projeto, não investigação de API externa — nenhum exemplo real anterior usava `params`/`requestBody`):

- `params`: `{"items":[{"name":"...","in":"query"|"header","required":bool,"type":"string"|"integer"|"number"|"boolean","description":"..."}]}` — embrulhado em objeto (chave `"items"`), porque só está confirmado neste projeto que `JsonObject():New():FromJson()` parseia um JSON top-level **objeto**; nunca foi testado com um array solto, e o custo de embrulhar é zero.
- `requestBody`: `{"required":bool,"description":"...","ref":"NomeDoComponente"}` — `ref` aponta para um schema já registrado no `OApiDoc` alvo (ex.: `HelloRequest`), sem redeclarar o schema inteiro dentro da annotation.

Implementada a classe `OApiAdpMeta` (`src/adapters/custom.openapi.adapter.metadata.tlpp`) com `toQueryParams(cParamsJson)` (gera `OApiParam` de query/header com schema primitivo) e `toBody(cBodyJson)` (gera `OApiBody` com schema `ref`). Ambos toleram string vazia ou JSON inválido devolvendo array vazio / `Nil`, sem lançar exceção.

Os dois exemplos-alvo foram atualizados para usar o novo formato:
- `custom.openapi.hello.get.tlpp`: `params='{"items":[{"name":"language","in":"query","required":false,"type":"string","description":"..."}]}'`
- `custom.openapi.hello.post.tlpp`: `requestBody='{"required":true,"description":"...","ref":"HelloRequest"}'`

**Contrato estático:** `tests/openapi-tlpp-adapter/validate-sources.py` estendido com `check_metadata_class()` — `Contrato do adaptador TL++ válido.` Regressão do contrato do núcleo (`tests/openapi-core/validate-sources.py`) também confirmada após editar os dois exemplos.

**Compilação:** os 4 fontes (`custom.openapi.adapter.metadata.tlpp`, teste atualizado, `custom.openapi.hello.get.tlpp`, `custom.openapi.hello.post.tlpp`) compilaram `[SUCCESS]` no `P12_2510`.

**PROBAT:** fixture `OApiAdpTst` ampliado para 16 asserções (10 de T2/T3 + 6 novas) — sem `THREAD ERROR`. As novas asserções usam os valores reais de `params`/`requestBody` **descobertos** via `Reflection.getFunctionAnnotation` (não literais redigitados no teste), incluindo o caso de string vazia (`toQueryParams("")`/`toBody("")`).

**Disciplina de encoding aplicada:** os dois exemplos-alvo e o fixture de teste (todos já em CP1252 com acentos) foram reconvertidos para UTF-8 antes de cada edição e reconvertidos para CP1252 ao final, com verificação explícita de ausência de caracteres de substituição (`U+FFFD`) antes de cada gravação final — evitando repetir a corrupção descrita em T3.

## T5 — montador final (2026-09-25)

Implementada a classe `OApiAdpBuild` (`src/adapters/custom.openapi.adapter.build.tlpp`), método `build(oDoc, aVerbs, aSources)`: para cada verbo, descobre (`OApiAdpDsc`), converte path/params/body/responses (`OApiAdpPath`, `OApiAdpMeta`), agrupa operações por template de path (necessário porque `OApiDoc::addPath()` rejeita path repetido mesmo com operações diferentes — confirmado lendo `custom.openapi.document.tlpp:83-96`), e só então registra cada path uma única vez em `oDoc`.

`OApiAdpMeta` ganhou `toResponses()`. Para reaproveitar o mesmo parsing seguro já confirmado (`FromJson()` só testado com JSON top-level objeto), o atributo `responses` dos dois exemplos-alvo foi reformatado do array solto original (`'[{"statusCode":200,...}]'`) para o mesmo padrão embrulhado (`'{"items":[{"statusCode":200,"description":"...","ref":"HelloResponse"}]}'`), com `ref` opcional apontando para um componente já registrado no `OApiDoc` alvo.

**Contrato estático:** `tests/openapi-tlpp-adapter/validate-sources.py` estendido com `check_build_class()` — `Contrato do adaptador TL++ válido.` Regressão do contrato do núcleo confirmada novamente (os dois exemplos-alvo foram editados mais uma vez).

**Compilação:** os 5 fontes (`custom.openapi.adapter.build.tlpp`, `custom.openapi.adapter.metadata.tlpp` atualizado, teste atualizado, `custom.openapi.hello.get.tlpp`, `custom.openapi.hello.post.tlpp`) compilaram `[SUCCESS]` no `P12_2510`.

**PROBAT:** fixture `OApiAdpTst` ampliado para cerca de 31 asserções (16 de T2-T4 + ~15 novas) — sem `THREAD ERROR`. Cobertura do teste de montagem completa:

- `oFullDoc` recebe `OApiInfo` e os 3 components (`HelloRequest`, `HelloResponse`, `ErrorResponse`, com propriedades reais — schemas vazios teriam gerado pendência de validação);
- `OApiAdpBuild():New():build(oFullDoc, {"Get","Post"}, aAlvos)` monta os 2 paths automaticamente;
- `/api/v1/hello/{name}` (GET): 1 operação, 2 parâmetros (`name` path + `language` query), 1 resposta (`200` → `$ref: HelloResponse`);
- `/api/v1/hello` (POST): 1 operação, `requestBody` presente, 2 respostas (`200` → `HelloResponse`, `400` → `ErrorResponse`);
- `oFullDoc:validate()` devolve 0 pendências;
- chamar `build()` uma segunda vez com os mesmos alvos lança `UserException` ("Path duplicado no documento") — capturada via `Try/Catch`, confirmando que a validação de conflito já existente do núcleo continua em vigor sem nenhuma lógica extra no adaptador.

Este é o fechamento do ciclo completo da Fase 3: reflection → descoberta → conversão de path/parâmetros/body/responses → montagem do documento, com o `endpoint` (fonte da verdade) fluindo direto da annotation até o `OApiPath` final, sem nenhum ponto intermediário de redigitação manual — a classe de bug da sessão anterior (2026-09-24) é estruturalmente impossível neste fluxo.

## T6 — limitações de inferência e rastreabilidade final (2026-09-25)

### Limitações de inferência conhecidas

- **Reflection em métodos de classe:** este incremento cobre apenas `User Function` anotadas. Métodos anotados (`public Method` com `@Get`/etc.) não são descobertos — decisão do usuário (2026-09-25), por ser significativamente mais complexo (introspecção de classe + instância). Fica documentado como próximo passo, não implementado.
- **Tipos de retorno e parâmetros formais:** nunca são fonte de metadados. A convenção do framework é que toda `User Function` anotada não recebe parâmetros formais e retorna sempre `Logical` (resultado do envio HTTP via `oRest`) — confirmado pelos dois exemplos-alvo e pelos fontes de produção pesquisados. Todo parâmetro/corpo tem que vir de `params`/`requestBody` (este incremento) ou do próprio `endpoint` (path).
- **`params`/`requestBody`/`responses` são atributos textuais, não validados pelo framework:** o `tlppCore` aceita qualquer string nesses atributos sem checagem — a correção do formato é responsabilidade de quem escreve a annotation. `OApiAdpMeta` tolera JSON malformado ou string vazia devolvendo array vazio/`Nil`, nunca lançando exceção, mas também nunca avisa o autor de um erro de digitação nesses atributos.
- **Rotas dinâmicas (`sLoadURNs`/`jEndpoints`):** o mecanismo de registro sem annotation (usado por rotas geradas em runtime) não passa por `Reflection.getFunctionsByAnnotation()` e não é descoberto por este adaptador — fora do escopo desta fase.
- **Schemas reutilizáveis (`components/schemas`) não são descobertos automaticamente:** `OApiAdpBuild::build()` espera que o `OApiDoc` recebido já tenha `OApiInfo` e os components (`HelloRequest`, `HelloResponse`, `ErrorResponse`) registrados por quem chama — o adaptador só descobre paths/operações/parâmetros/body, nunca schemas de DTO. Definir schemas a partir de classes/annotations próprias é uma extensão natural para a Fase 5 (roadmap: "Schemas e padrões TOTVS").
- **`Reflection.getFunctionsByAnnotation()` enumera o RPO inteiro, não um arquivo:** o adaptador sempre processa todo o ambiente e filtra por `cSourceName`; não há como restringir a busca a um diretório ou a fontes ainda não compilados.
- **Escala:** este incremento foi validado com 2 fontes-alvo. Descoberta em escala (dezenas/centenas de arquivos) não foi testada nem otimizada.

### Rastreabilidade final (ADPT-01 a ADPT-15)

| Requisito | Componente | Estado |
| --- | --- | --- |
| ADPT-01 a ADPT-03 | Spike de verificação (T1) | Confirmado por evidência real (compilação + HTTP) |
| ADPT-04 a ADPT-06, ADPT-09 | `OApiAdpDsc::discover()` (T2) | Implementado e validado (PROBAT, compilação) |
| ADPT-07, ADPT-10 | `OApiAdpPath::toTemplate()`/`toParams()` (T3) | Implementado e validado (PROBAT, compilação) |
| ADPT-08 | `OApiDoc::addPath()` (núcleo, reaproveitado por `OApiAdpBuild`) | Implementado e validado (PROBAT) |
| ADPT-11, ADPT-12 | `OApiAdpMeta::toQueryParams()`/`toBody()`/`toResponses()` (T4/T5) | Implementado e validado (PROBAT, compilação) |
| ADPT-13, ADPT-14 | `OApiAdpBuild::build()` (T5) | Implementado e validado (PROBAT, compilação) |
| ADPT-15 | Este diário + README (T6) | Concluído |

**Cobertura:** 15/15 requisitos com evidência registrada. Nenhum item permanece "planejado sem justificativa" — as únicas lacunas remanescentes (reflection em métodos de classe, descoberta de schemas) são limitações deliberadas, documentadas acima com a razão de cada uma.

## Fontes de spike (descartáveis)

Os 7 fontes ficam em `examples/openapi-tlpp-adapter/custom.openapi.tlpp.spike.*.tlpp` (`control`, `enum`, `attr2`, `attr3`, `inspect`, `inspect2`, `inspect3`). Servem só como evidência reproduzível do spike; não fazem parte do adaptador final e podem ser removidos do RPO quando a implementação (T2 em diante) estiver concluída.
