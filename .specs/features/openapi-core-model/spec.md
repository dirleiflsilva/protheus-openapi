# Núcleo do modelo OpenAPI - Especificação

## Problema

O experimento comprovou que o gerador nativo documenta endpoints TL++, mas sua saída pode conter paths duplicados, usar CP1252 e omitir serviços AdvPL `WSRESTFUL`. A futura biblioteca precisa de um modelo próprio, independente da descoberta e do formato de saída, para representar e validar uma API de maneira previsível.

## Objetivos

- [ ] Construir em TL++ um modelo mínimo de documento OpenAPI 3.0.3.
- [ ] Serializar o modelo como JSON válido sem depender de `tlpp.doc.generate()`.
- [ ] Representar integralmente o endpoint Hello World já validado.
- [ ] Rejeitar ambiguidades e impedir serialização parcial.
- [ ] Demonstrar o núcleo por um endpoint REST reproduzível.

## Fora do escopo

| Item | Motivo |
| --- | --- |
| Importar ou normalizar o YAML nativo | o normalizador existente permanece como utilitário independente. |
| Descobrir annotations TL++ | será responsabilidade de um adaptador posterior. |
| Descobrir `WSRESTFUL` | exige parsing e metadados próprios em outra feature. |
| Parâmetros e request bodies | não são necessários para o vertical slice do Hello World. |
| Schemas, segurança, `servers` e `components` | pertencem à evolução do núcleo OpenAPI. |
| Gerar YAML | o primeiro serializador produzirá somente JSON. |
| Pretty-print | a apresentação legível será derivada fora do núcleo. |

## Histórias e critérios de aceitação

### P1: Construir o documento mínimo

**História:** Como desenvolvedor Protheus, quero compor um documento OpenAPI por objetos TL++ para não depender da estrutura produzida pelo gerador nativo.

1. **CORE-01:** QUANDO um documento for criado ENTÃO ele DEVE declarar `openapi` como `3.0.3`.
2. **CORE-02:** QUANDO informações da API forem adicionadas ENTÃO o modelo DEVE preservar título, descrição e versão.
3. **CORE-03:** QUANDO um path válido receber uma operação ENTÃO o modelo DEVE preservar path, verbo, resumo e descrição.
4. **CORE-04:** QUANDO uma resposta for adicionada ENTÃO o modelo DEVE preservar código HTTP e descrição.
5. **CORE-05:** QUANDO o Hello World for montado ENTÃO o modelo DEVE conter `GET /api/v1/hello` e a resposta `200` esperada.

**Teste independente:** montar o modelo em um teste TL++ e verificar cada valor sem serializá-lo.

### P1: Proteger invariantes estruturais

**História:** Como mantenedor, quero impedir estados ambíguos para que nenhum adaptador precise decidir silenciosamente qual operação manter.

1. **CORE-06:** QUANDO um path não começar com `/` ENTÃO a inclusão DEVE falhar imediatamente com diagnóstico do path.
2. **CORE-07:** QUANDO um verbo não pertencer à lista OpenAPI suportada ENTÃO a inclusão DEVE falhar imediatamente com diagnóstico do verbo.
3. **CORE-08:** QUANDO o mesmo verbo for adicionado novamente ao mesmo path ENTÃO a inclusão DEVE falhar sem substituir a operação original.
4. **CORE-09:** QUANDO o mesmo código de resposta for adicionado novamente à mesma operação ENTÃO a inclusão DEVE falhar sem substituir a resposta original.
5. **CORE-10:** QUANDO uma inclusão estrutural falhar ENTÃO o restante do modelo DEVE permanecer utilizável e inalterado.

**Teste independente:** executar casos negativos no RPO e confirmar erro, mensagem e preservação do primeiro valor.

### P1: Validar completude antes de serializar

**História:** Como consumidor da biblioteca, quero receber todas as incompletudes conhecidas de uma vez e impedir a publicação de um documento inválido.

1. **CORE-11:** QUANDO título, versão da API ou paths estiverem ausentes ENTÃO a validação DEVE retornar todas as pendências encontradas.
2. **CORE-12:** QUANDO uma operação não possuir resposta ENTÃO a validação DEVE informar o path e o verbo afetados.
3. **CORE-13:** QUANDO o modelo estiver incompleto ENTÃO o serializador DEVE rejeitar a geração.
4. **CORE-14:** QUANDO a serialização falhar ENTÃO nenhum JSON parcial DEVE ser retornado.

**Teste independente:** montar um documento com múltiplas pendências, validar a lista completa e comprovar a recusa do serializador.

### P1: Serializar e publicar o Hello World

**História:** Como leitor do projeto, quero acessar um endpoint que retorne o documento criado pela biblioteca para reproduzir e validar o aprendizado.

1. **CORE-15:** QUANDO um modelo completo for serializado ENTÃO o resultado DEVE ser JSON estruturalmente equivalente ao OpenAPI esperado, independentemente da ordem das propriedades.
2. **CORE-16:** QUANDO o endpoint `/api/v1/openapi/core` for chamado com autenticação válida ENTÃO ele DEVE responder HTTP `200` e `application/json`.
3. **CORE-17:** QUANDO o corpo retornado for validado ENTÃO ele DEVE ser aceito como OpenAPI 3.0.3 e conter `GET /api/v1/hello`.
4. **CORE-18:** QUANDO o endpoint for chamado sem credenciais no ambiente com `SECURITY=1` ENTÃO o AppServer DEVE preservar o comportamento HTTP `401`.

**Teste independente:** compilar, chamar o endpoint com e sem autenticação e validar o JSON capturado com o validador do projeto.

## Casos-limite

- Comparações de paths, verbos e códigos não podem descartar dados silenciosamente.
- Verbos aceitos devem ser normalizados para minúsculas antes do armazenamento.
- Código de resposta é tratado como chave textual para permitir evolução futura para `default` e intervalos; o MVP exige `200`.
- Arrays retornados por getters não devem permitir substituir silenciosamente coleções internas.
- Os testes não devem depender da ordem textual das propriedades JSON.
- Falhas de validação devem usar mensagens sem dados de ambiente ou credenciais.

## Rastreabilidade

| Requisito | História | Estado |
| --- | --- | --- |
| CORE-01 a CORE-05 | Construir o documento mínimo | Em design |
| CORE-06 a CORE-10 | Proteger invariantes | Em design |
| CORE-11 a CORE-14 | Validar completude | Em design |
| CORE-15 a CORE-18 | Serializar e publicar | Em design |

**Cobertura:** 18 requisitos, 18 mapeados no design, 0 não mapeados.

## Critérios de sucesso

- [ ] Todos os fontes compilam no ambiente `P12_2510` após conversão para Windows-1252 sem BOM.
- [ ] Testes do núcleo cobrem construção, conflitos, incompletudes e serialização.
- [ ] O endpoint autenticado retorna um OpenAPI 3.0.3 válido equivalente ao Hello World.
- [ ] Nenhum fonte do núcleo chama `tlpp.doc.generate()`.
- [ ] O design registra limitações e referências suficientes para um post técnico reproduzível.
