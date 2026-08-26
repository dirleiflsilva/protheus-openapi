# Parâmetros e schemas OpenAPI - Decisões

**Data:** 2026-08-26
**Estado:** aprovado

## Decisões do usuário

| Tema | Decisão |
| --- | --- |
| Profundidade | piloto mínimo com parâmetros, objetos, arrays simples, `$ref`, components, request body e schemas de resposta. |
| Alimentação | montagem manual pelo modelo; descoberta automática permanece nos adaptadores futuros. |
| Demonstração | criar GET com path/query e POST com request/response reais. |
| Arquitetura | classes tipadas por responsabilidade, sem fragmentos `JsonObject` no domínio. |
| Media type | somente `application/json` neste incremento. |
| Validação | ambiguidades falham imediatamente; incompletudes e referências quebradas são acumuladas antes da serialização. |
| Forma do schema | discriminante explícito para primitivo, `object`, `array` ou `ref`; cada forma aceita somente seus próprios mutadores. |
| Identidade de parâmetro | `in` em minúsculas; nome preservado, sensível a caixa em path/query e insensível em header. |
| Payload do piloto | `HelloRequest` contém name/language; `HelloResponse` contém message/language/status; `ErrorResponse` contém message/status. |

## Discrição do agente

- Nomes exatos dos métodos públicos, respeitando o limite prático de 10 caracteres e os padrões existentes.
- Organização interna de propriedades e componentes, sem expor detalhes do armazenamento.
- Organização interna dos payloads, sem alterar os campos mínimos e comportamentos registrados.
- Mensagens exatas dos diagnósticos, mantendo contexto, estabilidade e segurança.

## Itens adiados

- Annotations próprias, reflection e inferência automática.
- Adaptador `WSRESTFUL`, SX3 e metadados externos.
- Composição avançada de schemas, formatos e validações de valor.
- Múltiplos media types, YAML e interface Swagger UI.
