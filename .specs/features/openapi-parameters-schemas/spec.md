# Parâmetros e schemas OpenAPI - Especificação

## Problema

O núcleo atual representa informações da API, paths, operações e respostas, mas ainda não descreve entradas e estruturas de dados. Para avançar até um piloto operacional, o modelo precisa representar parâmetros, request bodies e schemas reutilizáveis sem se acoplar ao REST, a `JsonObject` ou à descoberta automática de endpoints.

## Objetivos

- [ ] Representar parâmetros `path`, `query` e `header` com schemas primitivos.
- [ ] Representar schemas primitivos, objetos, arrays e referências reutilizáveis.
- [ ] Publicar request bodies e schemas de resposta em `application/json`.
- [ ] Serializar `components/schemas` sem permitir referências inválidas.
- [ ] Demonstrar o modelo por endpoints GET e POST executáveis.

## Fora do escopo

| Item | Motivo |
| --- | --- |
| Descoberta automática de annotations TL++ | será implementada por um adaptador posterior. |
| Análise de fontes `WSRESTFUL` | pertence ao futuro adaptador AdvPL. |
| Inferência de payloads ou leitura do SX3 | exige regras próprias e dados externos ao núcleo. |
| `cookie`, múltiplos media types e upload | não são necessários para o piloto mínimo. |
| `enum`, formatos, `nullable`, `allOf`, `oneOf` e `anyOf` | ficam para evolução posterior do modelo. |
| YAML e Swagger UI | pertencem à etapa de distribuição do piloto. |

## Histórias e critérios de aceitação

### P1: Representar schemas mínimos

**História:** Como autor de uma API Protheus, quero descrever estruturas de entrada e saída sem escrever fragmentos JSON manualmente.

1. **PSCH-01:** QUANDO um schema for criado ENTÃO o discriminante DEVE aceitar somente `string`, `integer`, `number`, `boolean`, `object`, `array` ou `ref`; qualquer outro valor DEVE falhar imediatamente.
2. **PSCH-02:** QUANDO um schema de objeto receber propriedades ENTÃO nome, schema e obrigatoriedade DEVEM ser preservados.
3. **PSCH-03:** QUANDO um schema de array for criado ENTÃO ele DEVE exigir um schema em `items`.
4. **PSCH-04:** QUANDO um schema `ref` receber o nome de um componente válido ENTÃO ele DEVE apontar exclusivamente para `#/components/schemas/<nome>`.
5. **PSCH-05:** QUANDO um mutador incompatível com o discriminante, uma segunda atribuição, uma propriedade duplicada ou um componente duplicado criar ambiguidade ENTÃO a operação DEVE falhar antes de alterar o estado.

### P1: Representar parâmetros e request body

**História:** Como consumidor do núcleo, quero associar entradas às operações para gerar contratos utilizáveis.

1. **PSCH-06:** QUANDO um parâmetro for criado ENTÃO sua localização DEVE ser `path`, `query` ou `header`.
2. **PSCH-07:** QUANDO a localização for `path` ENTÃO `required` DEVE ser verdadeiro.
3. **PSCH-08:** QUANDO dois parâmetros tiverem o mesmo `in + name` na operação ENTÃO o segundo DEVE ser rejeitado sem substituir o primeiro.
4. **PSCH-09:** QUANDO uma operação receber parâmetros válidos ENTÃO a ordem de inclusão DEVE ser preservada para serialização.
5. **PSCH-10:** QUANDO uma operação receber request body ENTÃO descrição, obrigatoriedade e schema JSON DEVEM ser preservados.
6. **PSCH-11:** QUANDO uma operação já possuir request body ENTÃO uma substituição silenciosa DEVE ser rejeitada.

### P1: Validar e serializar referências

**História:** Como mantenedor, quero impedir a publicação de documentos com estruturas incompletas ou referências quebradas.

1. **PSCH-12:** QUANDO uma resposta possuir schema ENTÃO ele DEVE ser publicado em `content.application/json.schema`.
2. **PSCH-13:** QUANDO um parâmetro, body, resposta ou propriedade referenciar componente inexistente ENTÃO a validação DEVE acumular uma pendência com contexto.
3. **PSCH-14:** QUANDO o documento estiver completo ENTÃO o JSON DEVE conter `parameters`, `requestBody`, `content` e `components/schemas` estruturalmente equivalentes ao modelo.
4. **PSCH-15:** QUANDO houver qualquer pendência ENTÃO o serializador DEVE falhar antes de devolver JSON parcial.

### P1: Demonstrar o incremento por REST

**História:** Como leitor do projeto, quero executar endpoints reais e conferir o documento produzido pela biblioteca.

1. **PSCH-16:** QUANDO `GET /api/v1/hello/{name}` for chamado com autenticação ENTÃO ele DEVE usar o parâmetro de path e aceitar `language` como query opcional.
2. **PSCH-17:** QUANDO `POST /api/v1/hello` receber um `HelloRequest` com `name` textual não vazio ENTÃO ele DEVE responder `200` com `HelloResponse`.
3. **PSCH-18:** QUANDO o POST receber JSON malformado, `name` ausente, vazio ou não textual ENTÃO ele DEVE responder `400` com `ErrorResponse` genérico, sem expor detalhes internos.
4. **PSCH-19:** QUANDO `/api/v1/openapi/core` for chamado ENTÃO o documento DEVE conter as duas operações e os três schemas reutilizáveis.
5. **PSCH-20:** QUANDO qualquer endpoint for chamado sem autenticação no ambiente com `SECURITY=1` ENTÃO o AppServer DEVE preservar HTTP `401`.

## Casos-limite

- `OApiSchema:new()` recebe exatamente um discriminante: `string`, `integer`, `number`, `boolean`, `object`, `array` ou `ref`.
- `addProp()` é exclusivo de `object`, `setItems()` de `array` e `setRef()` de `ref`; formas primitivas não aceitam esses mutadores.
- Uma segunda chamada a `setItems()` ou `setRef()` falha antes da mutação; objetos rejeitam propriedades repetidas.
- Nomes de components e refs devem ser não vazios e usar somente letras ASCII, números, ponto, hífen ou sublinhado.
- Objetos sem propriedades, arrays sem `items` e refs sem nome são incompletos.
- `in` é aparado e normalizado para minúsculas; o nome é aparado e preserva caixa. A identidade usa nome exato em `path`/`query` e nome sem distinção de caixa em `header`.
- A serialização preserva o nome original do parâmetro, inclusive para corresponder ao placeholder do path.
- O núcleo não deve assumir que request body é permitido ou proibido por verbo; essa política pertence a uma camada superior.
- Getters de coleções devem proteger a composição dos arrays internos, documentando que `AClone()` é cópia rasa.
- Mensagens de validação não devem conter credenciais, paths locais ou stack trace.

## Contratos da demonstração

| Schema | Propriedades |
| --- | --- |
| `HelloRequest` | `name: string` obrigatório; `language: string` opcional. |
| `HelloResponse` | `message: string`, `language: string` e `status: string`, todos obrigatórios. |
| `ErrorResponse` | `message: string` e `status: string`, ambos obrigatórios. |

- GET usa `name` do path e `language` opcional da query; ausente ou vazia, `language` assume `TL++`.
- GET `200` e POST `200` retornam `HelloResponse` com `message = "Hello " + name`, a linguagem efetiva e `status = "success"`.
- POST usa `language` opcional do body com o mesmo default `TL++`.
- POST `400` retorna `{"message":"Payload inválido.","status":"error"}`.

## Rastreabilidade

| Requisitos | Componente planejado | Estado |
| --- | --- | --- |
| PSCH-01 a PSCH-05 | `OApiSchema`, `OApiDoc` | Implementado — contrato estático aprovado; PROBAT não executado |
| PSCH-06 a PSCH-11 | `OApiParam`, `OApiBody`, `OApiOper` | Implementado — contrato estático aprovado; PROBAT não executado |
| PSCH-12 a PSCH-15 | `OApiResp`, `OApiJson`, validação transitiva | Implementado — contrato estático e serialização estrutural aprovados; PROBAT não executado |
| PSCH-16 a PSCH-20 | endpoints de demonstração e validação HTTP | Implementado — símbolos `oRest` conferidos contra fontes padrão do Protheus; compilação e HTTP real não executados |

**Cobertura:** 20 requisitos, 20 mapeados no design, 0 não mapeados. Ver [diário técnico](../../../docs/experiments/openapi-parameters-schemas.md) para a rastreabilidade requisito a requisito e o detalhamento do que foi e não foi verificado em runtime.

## Critérios de sucesso

- [ ] Fontes TL++ compilam no `P12_2510` em Windows-1252 sem BOM — encoding confirmado; compilação real não executada nesta sessão.
- [ ] PROBAT cobre construção, conflitos, referências, completude e serialização — testes escritos com essa cobertura; execução real do PROBAT no RPO pendente.
- [x] Contratos PowerShell e regressões existentes permanecem aprovados.
- [ ] GET, POST válido, POST inválido, OpenAPI e autenticação são comprovados no runtime — pendente; requer AppServer.
- [x] Documento final contém parâmetros, request body, responses e três schemas reutilizáveis (verificado estruturalmente via `JsonObject`; comportamento HTTP ainda não verificado).
