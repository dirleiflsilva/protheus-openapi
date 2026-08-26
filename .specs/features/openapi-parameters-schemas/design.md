# Parâmetros e schemas OpenAPI - Design

**Especificação:** `.specs/features/openapi-parameters-schemas/spec.md`
**Decisões:** `.specs/features/openapi-parameters-schemas/context.md`
**Estado:** aprovado em 2026-08-26

## Arquitetura

O núcleo continuará independente de REST e `JsonObject`. Três classes tipadas serão adicionadas a `custom.openapi.core`: `OApiSchema`, `OApiParam` e `OApiBody`. As entidades existentes serão estendidas somente para compor e validar essas estruturas; `OApiJson` continuará sendo a única camada conhecedora do formato de saída.

```text
OApiSchema ──> components/schemas
     ↑                    ↑
OApiParam ──> OApiOper ──> OApiPath ──> OApiDoc ──> OApiJson
OApiBody  ──────┘             ↑
OApiResp  ────────────────────┘
```

## Abordagens avaliadas

| Abordagem | Decisão |
| --- | --- |
| Classes tipadas por responsabilidade | escolhida; preserva validação e independência do serializador. |
| Fragmentos `JsonObject` | rejeitada; acopla domínio à saída e permite estados inválidos. |
| Builder genérico de toda a especificação | adiada; flexibilidade desnecessária para o piloto. |

## Componentes

| Componente | Responsabilidade |
| --- | --- |
| `OApiSchema` | representar primitivo, objeto, array ou `$ref`; manter propriedades únicas e validar sua forma. |
| `OApiParam` | representar nome, localização, descrição, obrigatoriedade e schema. |
| `OApiBody` | representar descrição, obrigatoriedade e schema JSON do request body. |
| `OApiOper` | manter parâmetros únicos e um request body opcional. |
| `OApiResp` | aceitar schema opcional para conteúdo JSON. |
| `OApiDoc` | registrar schemas reutilizáveis com nomes únicos e validar referências transitivamente. |
| `OApiJson` | serializar parâmetros, body, conteúdo de respostas e components após validação completa. |

## Interfaces planejadas

Os nomes finais serão confirmados contra macros e símbolos locais antes da implementação.

```text
OApiSchema:new(cKind)
OApiSchema:addProp(cName, oSchema, lReq)
OApiSchema:setItems(oSchema)
OApiSchema:setRef(cName)
OApiParam:new(cName, cIn, lReq, oSchema, cDesc)
OApiBody:new(lReq, oSchema, cDesc)
OApiOper:addParam(oParam)
OApiOper:setBody(oBody)
OApiResp:setSchema(oSchema)
OApiDoc:addSchema(cName, oSchema)
```

Getters devolverão escalares ou cópias rasas das coleções. Objetos contidos continuarão compartilhados, como no núcleo existente.

`cKind` é aparado, normalizado para minúsculas e aceita somente `string`, `integer`, `number`, `boolean`, `object`, `array` ou `ref`. `addProp()` opera apenas em `object`; `setItems()` apenas em `array`; `setRef()` apenas em `ref`. Repetir `setItems()`/`setRef()`, combinar formas ou usar um mutador incompatível gera `UserException()` antes de alterar o objeto. O schema `ref` nasce com discriminante próprio e permanece incompleto somente até receber um nome, evitando a combinação artificial entre `$ref` e tipo.

Nomes de components e referências aceitam somente `[A-Za-z0-9._-]` e não podem ser vazios. O modelo armazena somente o nome; o serializador produz `#/components/schemas/<nome>`.

Em parâmetros, `cIn` é aparado e convertido para minúsculas. `cName` é aparado, mas sua caixa é preservada na saída. A chave de duplicidade usa o nome exato em `path` e `query`; em `header`, usa o nome em minúsculas, respeitando a natureza case-insensitive dos cabeçalhos HTTP.

## Invariantes e validação

Tipos ou localizações desconhecidos, formas híbridas, propriedades/componentes/parâmetros duplicados e substituição do body falham por `UserException()` antes da mutação. `validate()` acumula campos vazios, path não obrigatório, array sem items, objeto sem propriedades, body sem schema e referências inexistentes. O documento resolve referências a partir do registro de components e acrescenta contexto de path, verbo, parâmetro, resposta ou propriedade.

`OApiJson:toJson()` valida tudo antes de criar a árvore JSON. O único media type emitido será `application/json`; referências serão serializadas como `#/components/schemas/<nome>`.

## Demonstração REST

- `GET /api/v1/hello/{name}`: path `name`, query opcional `language` e resposta `HelloResponse`.
- `POST /api/v1/hello`: body `HelloRequest`, resposta `200` com `HelloResponse` e `400` com `ErrorResponse`.
- `GET /api/v1/openapi/core`: publica o documento enriquecido.

`HelloRequest` possui `name` obrigatório e `language` opcional. `HelloResponse` possui `message`, `language` e `status` obrigatórios. `ErrorResponse` possui `message` e `status` obrigatórios. A linguagem assume `TL++` quando ausente ou vazia. GET e POST válidos retornam `message = "Hello " + name` e `status = "success"`. JSON malformado ou `name` ausente, vazio ou não textual retorna `400` com `{"message":"Payload inválido.","status":"error"}`.

A sintaxe exata das annotations e do acesso a path, query e body será validada nos fontes locais da release antes da geração. O AppServer continua responsável por autenticação e HTTP `401`.

## Estratégia de testes

O ciclo TDD usa PROBAT para cada entidade e regra. Contratos PowerShell verificam estrutura, ProtheusDOC, APIs, CP1252 sem BOM e dependências proibidas. A fixture JSON cobre múltiplos parâmetros, objetos, array, `$ref`, request body, schemas de resposta e components. Depois da compilação, o runtime comprova `401`, GET, POST `200`, POST `400` e documento OpenAPI enriquecido.

## Rastreabilidade do design

| Requisitos | Decisão ou componente |
| --- | --- |
| PSCH-01 a PSCH-05 | `OApiSchema` e registro em `OApiDoc`. |
| PSCH-06 a PSCH-11 | `OApiParam`, `OApiBody` e extensões de `OApiOper`. |
| PSCH-12 a PSCH-15 | `OApiResp`, resolução transitiva e `OApiJson`. |
| PSCH-16 a PSCH-20 | endpoints reais, fixture e validação HTTP. |

## Limitações deliberadas

- O modelo não pretende cobrir toda a OpenAPI 3.0.3 neste incremento.
- O núcleo não conhece annotations, `oRest`, filesystem, autenticação ou ambiente.
- Schemas não validam valores de payload em runtime; descrevem e validam o contrato OpenAPI.
- O motor PROBAT continua sendo executado no RPO pelo TDS/AppServer.
