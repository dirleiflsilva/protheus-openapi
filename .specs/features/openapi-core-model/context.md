# Núcleo do modelo OpenAPI - Decisões

**Data:** 2026-08-21
**Estado:** aprovado

## Decisões do usuário

| Tema | Decisão |
| --- | --- |
| Primeiro incremento | construir o modelo intermediário e o serializador JSON antes dos adaptadores. |
| Versão OpenAPI | produzir inicialmente OpenAPI `3.0.3`. |
| Separação | manter modelo, serializador e adaptadores em responsabilidades distintas. |
| Validação | usar estratégia híbrida: invariantes estruturais falham imediatamente; incompletudes são acumuladas antes da serialização. |
| Demonstração | expor um endpoint REST separado que gere o OpenAPI do Hello World com a biblioteca. |
| Saída | retornar JSON compacto; formatação legível pertence aos testes e à documentação. |
| Escopo inicial | `info`, `paths`, operação `get` e resposta `200` do Hello World. |
| Conteúdo editorial | organizar o desenvolvimento em incrementos demonstráveis e reutilizáveis nos posts do blog. |

## Decisões técnicas

- Usar o namespace de customização `custom.openapi.core`; namespaces iniciados por `tlpp` ou `core` são reservados.
- Manter nomes próprios de classes e métodos com até 10 caracteres sempre que aplicável.
- Usar um fonte TL++ por classe para favorecer manutenção e explicação didática.
- Usar `JsonObject():New()` e `ToJson()`, confirmados nos fontes locais e no experimento Hello World.
- Usar `UserException()` para impedir violações estruturais e serialização inválida, após validação em fontes locais.
- Avaliar PROBAT por um teste de fumaça antes de adotá-lo. A implementação não usará `Function` nem declarará `U_` explicitamente para contornar incompatibilidades.
- Manter testes PowerShell de contrato como gate independente do RPO.

## Discrição do agente

- Mensagens exatas dos diagnósticos, desde que sejam estáveis, em português e identifiquem campo ou conflito.
- Organização interna dos arrays do modelo, sem expor dependência do formato de armazenamento na API pública.
- Ordem de construção dos `JsonObject`, pois os testes compararão estrutura e não texto bruto.

## Itens adiados

- YAML, `servers`, parâmetros, schemas, request bodies, segurança e `components`.
- Descoberta automática de annotations TL++.
- Leitura ou análise de fontes `WSRESTFUL`.
- Formatação pretty-print dentro da biblioteca.
