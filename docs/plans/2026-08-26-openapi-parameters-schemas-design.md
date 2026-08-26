# Parâmetros e schemas OpenAPI - Design aprovado

**Data:** 2026-08-26
**Especificação:** `.specs/features/openapi-parameters-schemas/spec.md`
**Design detalhado:** `.specs/features/openapi-parameters-schemas/design.md`

## Decisão

Evoluir o núcleo manual com parâmetros e schemas tipados antes de iniciar a descoberta automática. O recorte inclui parâmetros `path`, `query` e `header`, schemas primitivos, objetos, arrays simples, referências, `components/schemas`, request body e schemas JSON de resposta.

## Componentes

```text
OApiSchema ──> components/schemas
     ↑                    ↑
OApiParam ──> OApiOper ──> OApiPath ──> OApiDoc ──> OApiJson
OApiBody  ──────┘             ↑
OApiResp  ────────────────────┘
```

O modelo permanece independente de REST e `JsonObject`; ambiguidades falham antes da mutação e incompletudes são acumuladas antes da serialização.

`OApiSchema` usa um discriminante explícito entre primitivos, `object`, `array` e `ref`; cada forma aceita somente seus mutadores compatíveis. Components e refs usam nomes restritos e o serializador monta o caminho `#/components/schemas/<nome>`.

## Demonstração

O piloto terá `GET /api/v1/hello/{name}`, `POST /api/v1/hello` e o documento enriquecido em `GET /api/v1/openapi/core`. Os schemas reutilizáveis serão `HelloRequest`, `HelloResponse` e `ErrorResponse`, todos em `application/json`.

O request possui `name` obrigatório e `language` opcional, com default `TL++`. Sucesso retorna `message`, `language` e `status`; payload POST malformado ou sem `name` textual não vazio retorna `400` com erro genérico.

## Resultado esperado

O marco estará concluído quando os fontes compilarem no `P12_2510`, o PROBAT e os gates locais passarem, os endpoints reais retornarem os códigos esperados e o OpenAPI publicado contiver parâmetros, request body, schemas de resposta e `components/schemas` sem referências quebradas.

## Sequência posterior

Após este incremento, o modelo estará pronto para receber metadados do adaptador de annotations TL++ e, em seguida, do adaptador de fontes `WSRESTFUL` AdvPL.
