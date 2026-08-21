# Núcleo do modelo OpenAPI - Design aprovado

**Data:** 2026-08-21
**Especificação:** `.specs/features/openapi-core-model/spec.md`
**Design detalhado:** `.specs/features/openapi-core-model/design.md`

## Decisão

Construir primeiro um modelo intermediário OpenAPI 3.0.3 em TL++, separado da descoberta de endpoints e da serialização. Essa ordem cria uma base comum para futuros adaptadores TL++ e AdvPL e uma sequência didática adequada aos posts do projeto.

## Componentes

```text
OApiInfo -> OApiDoc -> OApiPath -> OApiOper -> OApiResp
                 |                         |
                 +------ validate() -------+
                              |
                           OApiJson
                              |
                  GET /api/v1/openapi/core
```

- O modelo não conhece REST-DOC, `WSRESTFUL`, arquivos ou YAML.
- O serializador só recebe documentos completos.
- Invariantes ambíguas falham imediatamente.
- Incompletudes são acumuladas por `validate()`.
- O endpoint de demonstração é cliente da biblioteca e reproduz o OpenAPI do Hello World.

## Resultado do primeiro marco

O marco estará concluído quando o ambiente `P12_2510` compilar os fontes e uma chamada autenticada a `/api/v1/openapi/core` retornar um JSON OpenAPI 3.0.3 válido contendo `GET /api/v1/hello` e sua resposta `200`, sem chamar `tlpp.doc.generate()`.

## Sequência editorial

Este incremento sustentará um post sobre modelagem de domínio, classes e validação em TL++, seguido por outro sobre serialização com `JsonObject`, testes PROBAT e publicação do documento por REST.
