# Núcleo do modelo OpenAPI - Design

**Especificação:** `.specs/features/openapi-core-model/spec.md`
**Decisões:** `.specs/features/openapi-core-model/context.md`
**Estado:** aprovado em 2026-08-21

## Arquitetura

O núcleo será um conjunto de classes TL++ no namespace `custom.openapi.core`. As classes representam dados e regras OpenAPI sem conhecer REST-DOC, annotations, `WSRESTFUL`, filesystem ou YAML. O serializador percorre somente um modelo validado e produz um `JsonObject`; o endpoint de demonstração permanece em `examples/` e atua como cliente da biblioteca.

```text
OApiInfo -> OApiDoc -> OApiPath -> OApiOper -> OApiResp
                 |                         |
                 +------ validate() -------+
                              |
                           OApiJson
                              |
                      JSON OpenAPI 3.0.3
                              |
                  GET /api/v1/openapi/core
```

## Abordagens avaliadas

| Abordagem | Decisão |
| --- | --- |
| Modelo próprio seguido de adaptadores | escolhida; reduz acoplamento e cria base comum para TL++ e AdvPL. |
| Pós-processar apenas o YAML do TLPPCore | mantida como utilitário experimental, não como arquitetura central. |
| Começar pelo parser `WSRESTFUL` | adiada; faltaria um contrato estável para receber os metadados. |
| Entidades serializando a si mesmas | rejeitada; mistura domínio e formato de saída. |

## Componentes

| Componente | Local | Responsabilidade |
| --- | --- | --- |
| `OApiInfo` | `src/core/custom.openapi.info.tlpp` | armazenar e validar título, descrição e versão da API. |
| `OApiResp` | `src/core/custom.openapi.response.tlpp` | representar uma resposta HTTP mínima. |
| `OApiOper` | `src/core/custom.openapi.operation.tlpp` | manter verbo, resumo, descrição e respostas sem duplicidade. |
| `OApiPath` | `src/core/custom.openapi.path.tlpp` | manter um path iniciado por `/` e operações únicas por verbo. |
| `OApiDoc` | `src/core/custom.openapi.document.tlpp` | representar a raiz 3.0.3, info e paths; acumular incompletudes. |
| `OApiJson` | `src/core/custom.openapi.json.tlpp` | validar o documento, criar objetos JSON aninhados e chamar `ToJson()`. |
| endpoint | `examples/openapi-core/custom.openapi.core.api.tlpp` | montar o Hello World e retornar o JSON por REST. |
| testes PROBAT | `tests/openapi-core/custom.openapi.core.test.tlpp` | executar construção, invariantes, validação e serialização no RPO. |
| contratos locais | `tests/openapi-core/validate-sources.ps1` | conferir documentação, dependências proibidas e estrutura mínima antes da compilação. |

## Interfaces públicas planejadas

Os nomes são deliberadamente curtos. A implementação deverá conservar tipagem explícita e declarar os métodos na classe antes de implementá-los.

```text
OApiInfo:new(cTitle, cDesc, cVer)
OApiResp:new(cCode, cDesc)
OApiOper:new(cMethod, cSummary, cDesc)
OApiOper:addResp(oResp)
OApiPath:new(cPath)
OApiPath:addOper(oOper)
OApiDoc:new(oInfo)
OApiDoc:addPath(oPath)
OApiDoc:validate() -> array
OApiJson:toJson(oDoc) -> character
```

Getters pequenos fornecerão ao serializador acesso somente leitura aos valores necessários. O armazenamento interno usará arrays de objetos, preservando a ordem de inclusão; essa ordem não fará parte do contrato JSON.

## Validação híbrida

Invariantes que tornariam o estado ambíguo são verificadas no construtor ou no método de inclusão e geram `UserException()` imediatamente: path sem `/`, verbo fora da lista, verbo duplicado e resposta duplicada. A inclusão só altera a coleção depois de todas as verificações, preservando o estado anterior em caso de erro.

Campos que podem estar temporariamente incompletos durante a montagem são verificados por `validate()`. A validação retorna um array com todas as mensagens, incluindo título ou versão vazios, ausência de paths e operação sem resposta. `OApiJson:toJson()` chama essa validação e gera `UserException()` antes de criar o JSON quando houver qualquer pendência; portanto, nunca retorna conteúdo parcial.

## Serialização

`OApiJson` criará a seguinte estrutura com `JsonObject():New()`:

```json
{
  "openapi": "3.0.3",
  "info": {
    "title": "Hello World API",
    "description": "API de demonstração do núcleo OpenAPI.",
    "version": "1.0.0"
  },
  "paths": {
    "/api/v1/hello": {
      "get": {
        "summary": "Hello World",
        "description": "Retorna uma mensagem Hello World gerada por um endpoint TL++.",
        "responses": {
          "200": {
            "description": "Hello World retornado com sucesso."
          }
        }
      }
    }
  }
}
```

## Endpoint de demonstração

O endpoint `GET /api/v1/openapi/core` usará `using namespace custom.openapi.core`, montará as entidades, chamará `OApiJson:toJson()` e retornará `application/json`. O núcleo não receberá referência a `oRest`. Uma falha inesperada será convertida pelo endpoint em resposta HTTP `500`, sem expor stack trace ou detalhes internos.

## Estratégia de testes

O diretório de includes contém `tlpp-probat.th`, e a documentação oficial confirma o PROBAT como motor nativo para testes TL++ e TDD. Como o exemplo oficial encontrado usa `Function U_...`, o primeiro passo será um smoke test com `@TestFixture()` sobre `User Function`, respeitando as regras do projeto. Se essa forma não for descoberta pelo motor, os mesmos cenários serão executados por um harness REST exclusivo de testes; `Function` e declaração explícita de `U_` não serão adotados.

O gate será composto por:

1. testes PowerShell de contrato;
2. testes unitários TL++ no RPO, preferencialmente PROBAT;
3. conversão dos fontes para Windows-1252 sem BOM;
4. compilação no ambiente `P12_2510`;
5. HTTP `401` sem credenciais e `200` autenticado;
6. validação estrutural do JSON capturado com `scripts/validate-hello-openapi.ps1`.

## Pesquisa e símbolos confirmados

| Símbolo ou recurso | Evidência |
| --- | --- |
| `JsonObject():New()` e `ToJson()` | fontes Hello World e exemplos locais TOTVS/SUPORTE. |
| namespaces e `using namespace` | fontes locais TL++ e documentação oficial de Namespace. |
| classes e métodos TL++ | fontes locais da release 12.1.2510. |
| `UserException()` | fontes locais TOTVS e SUPORTE. |
| `try/catch/endTry` | fontes locais da release 12.1.2510. |
| `@TestFixture()`, `assertEquals()` e `assertError()` | repositório oficial `totvs/tlpp-probat-samples`. |
| annotations REST e `oRest` | fontes do experimento compilados no ambiente alvo. |

## Rastreabilidade do design

| Requisitos | Componentes ou decisões |
| --- | --- |
| CORE-01, CORE-02 | `OApiDoc`, `OApiInfo`. |
| CORE-03, CORE-04, CORE-05 | `OApiPath`, `OApiOper`, `OApiResp`. |
| CORE-06, CORE-07, CORE-08, CORE-09, CORE-10 | validações imediatas em `OApiPath` e `OApiOper`. |
| CORE-11, CORE-12, CORE-13, CORE-14 | `OApiDoc:validate()` e bloqueio em `OApiJson`. |
| CORE-15 | `OApiJson` e testes estruturais. |
| CORE-16, CORE-17, CORE-18 | endpoint de demonstração e validação HTTP. |

## Limitações deliberadas

- O modelo não representa toda a especificação OpenAPI 3.0.3.
- O serializador não lê nem corrige documentos externos.
- O núcleo não conhece autenticação, porta, ambiente ou localização de arquivos.
- A execução automatizada do PROBAT depende da confirmação do fluxo disponível no TDS/AppServer instalado.

## Referências

- `docs/experiments/hello-world.md`
- `examples/hello-world/hello-api.tlpp`
- `scripts/validate-hello-openapi.ps1`
- https://tdn.totvs.com/display/tec/PROBAT
- https://tdn.totvs.com/display/tec/Namespace
- https://github.com/totvs/tlpp-probat-samples
