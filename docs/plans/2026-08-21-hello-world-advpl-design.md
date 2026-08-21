# Hello World AdvPL - Design

**Especificação:** `.specs/features/hello-world-advpl/spec.md`

**Estado:** aprovado em 2026-08-21

## Abordagem

O experimento usará o mecanismo `WSRESTFUL` consolidado do AdvPL, no mesmo serviço REST e sob a mesma configuração de segurança do exemplo TL++. O endpoint não acessará banco de dados nem dependerá de parâmetros do ambiente.

Foram descartadas a concatenação manual de JSON e a adoção de `FWAdapterBaseV2`/TTALK, pois acrescentariam riscos ou comportamentos que não fazem parte da comparação mínima.

## Componente

| Item | Definição |
| --- | --- |
| Fonte | `examples/hello-world/hello-api-advpl.prw` |
| Includes | `totvs.ch` e `restful.ch` |
| Serviço | `api` |
| Método | `GET Hello` |
| Sintaxe | `/v1/hello-advpl` (URL final: `/rest/api/v1/hello-advpl`) |
| Formato | `APPLICATION_JSON` |
| Resposta | `JsonObject():New()`, `Self:SetContentType()` e `Self:SetResponse()` |
| Persistência | nenhuma |
| Segurança | herdada de `SECURITY=1` |

Os símbolos `WSRESTFUL`, `WSMETHOD`, `WSSYNTAX`, `PATH`, `PRODUCES`, `JsonObject():New()`, `Self:SetContentType()` e `Self:SetResponse()` foram confirmados nos fontes locais do release 12.1.2510 e nas referências de suporte do projeto.

## Contrato HTTP

O endpoint autenticado deverá responder HTTP `200` e `application/json` com:

```json
{
  "message": "Hello World",
  "language": "AdvPL",
  "status": "success"
}
```

A ausência de credenciais deverá continuar sendo tratada pela infraestrutura REST, resultando em HTTP `401`, sem lógica de autenticação no fonte.

## Fluxo de validação

1. Um teste estático falhará antes da criação do fonte e validará estrutura, rota e contrato.
2. O fonte será criado e convertido para Windows-1252 sem BOM.
3. O contrato estático e as verificações de encoding serão executados.
4. O usuário compilará o fonte no RPO REST `P12_2510`.
5. As chamadas sem e com autenticação comprovarão o comportamento HTTP.
6. O exportador nativo será executado novamente e somente os paths TL++ e AdvPL serão comparados.
7. A matriz registrará os dados observados e manterá as duplicidades globais do YAML como limitação independente.

## Artefatos e segurança

O YAML completo do ambiente não será versionado. O arquivo atualmente existente em `docs/hello_openapi_8084.yaml` continuará fora do Git. A documentação versionada conterá apenas a comparação necessária, sem credenciais, cabeçalhos de autorização ou catálogo de APIs do ambiente.

## Limitações esperadas

- `WSRESTFUL` pode fornecer menos metadados documentais que as annotations TL++; isso será medido, não presumido.
- O YAML agregado pode permanecer inválido devido a paths padrão duplicados.
- A geração de schemas, exemplos e parâmetros permanece fora desta feature.
