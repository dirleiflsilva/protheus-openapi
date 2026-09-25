# Adaptador para endpoints TL++ - Especificação

## Problema

A montagem do documento OpenAPI hoje é 100% manual: `examples/openapi-core/custom.openapi.core.api.tlpp` chama os construtores `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody` diretamente, duplicando à mão informações que já existem nas annotations `@Get`/`@Post`/`@Put`/`@Patch`/`@Delete` dos próprios endpoints. Essa duplicação já causou um bug real (2026-09-24): o `GET /api/v1/hello/:name` foi registrado sob o `OApiPath` errado (`/api/v1/hello`, sem `{name}`), só descoberto por verificação HTTP real — nem o PROBAT nem o contrato estático capturaram a divergência, porque nada compara o texto da annotation com o que foi montado manualmente.

Este incremento constrói um adaptador que lê a fonte da verdade (a própria annotation) e monta as instâncias `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody` por introspecção, eliminando essa classe de erro por construção.

## Objetivos

- [ ] Confirmar empiricamente (spike) o mecanismo real de reflection/leitura de annotations disponível no `tlppCore` desta versão.
- [ ] Reconhecer `User Function` anotadas com `@Get`, `@Post`, `@Put`, `@Patch` ou `@Delete`.
- [ ] Extrair endpoint, verbo, descrição e parâmetros disponíveis sem duplicação manual.
- [ ] Montar `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody` a partir da introspecção, usando o núcleo existente sem alterá-lo.
- [ ] Documentar o que não é derivável automaticamente e definir annotations complementares para essas lacunas.

## Fora do escopo

| Item | Motivo |
| --- | --- |
| Reflection em métodos de classe anotados | decisão do usuário (2026-09-25): só funções neste incremento; introspecção de instância é significativamente mais complexa. |
| Adaptador `WSRESTFUL`/AdvPL | pertence à Fase 4 do roadmap. |
| Alterações no núcleo `OApi*` | a Fase 3 consome o núcleo; só é alterado se uma lacuna real e documentada aparecer. |
| Descoberta em escala (diretórios inteiros, múltiplos arquivos) | este incremento cobre só os dois exemplos-alvo; escala fica para evolução posterior. |
| Rotas dinâmicas (`sLoadURNs`/`jEndpoints`, registro sem annotation) | fora do padrão `@Get`/`@Post` estático que é o alvo desta fase. |
| Tipos de retorno, comentários `Protheus.doc` como fonte de metadados | não são annotations; não são lidos pela API de reflection. |

## Histórias e critérios de aceitação

### P0: Verificar o mecanismo real de reflection (spike, pré-requisito)

**História:** Como mantenedor, quero confirmar com evidência de compilação real qual API de reflection existe nesta versão do `tlppCore`, para não desenhar o adaptador sobre uma suposição.

1. **ADPT-01:** QUANDO o spike for executado ENTÃO ele DEVE confirmar ou refutar, com evidência de compilação e execução reais no `P12_2510`, a existência de uma API capaz de localizar `User Function` anotadas com um verbo HTTP e ler os atributos textuais da annotation (endpoint, title, description, responses).
2. **ADPT-02:** QUANDO a API real for confirmada ENTÃO seu formato de retorno (nomes de campos, tipos, forma de acesso) DEVE ser documentado com uma captura real de execução sobre os dois exemplos-alvo.
3. **ADPT-03:** QUANDO a API documentada no TDN não corresponder ao que realmente compila ENTÃO o spike DEVE registrar o que de fato funciona, e o design deste incremento DEVE ser revisado com base nesse fato antes de continuar.

### P1: Reconhecer as annotations dos verbos HTTP

**História:** Como autor de uma API TL++, quero que o adaptador reconheça automaticamente minhas funções anotadas, sem registro manual adicional.

1. **ADPT-04:** QUANDO o adaptador processar `HeloGet` ENTÃO ele DEVE reconhecer `@Get` e extrair o verbo `GET`.
2. **ADPT-05:** QUANDO o adaptador processar `HeloPost` ENTÃO ele DEVE reconhecer `@Post` e extrair o verbo `POST`.
3. **ADPT-06:** QUANDO uma função no arquivo-alvo não tiver nenhuma annotation de verbo reconhecida ENTÃO o adaptador DEVE ignorá-la sem falhar e sem interromper a descoberta das demais.

### P2: Extrair path e descrição sem duplicação manual

**História:** Como mantenedor, quero que o path registrado no documento OpenAPI seja sempre derivado do texto real da annotation, para que a classe de bug da sessão anterior deixe de ser possível.

1. **ADPT-07:** QUANDO o endpoint for extraído da annotation ENTÃO o `OApiPath` resultante DEVE usar exatamente essa string, convertendo cada segmento `:nome` para `{nome}`, sem permitir que o path registrado diverja do texto anotado.
2. **ADPT-08:** QUANDO o mesmo path e verbo já existirem no `OApiDoc` alvo ENTÃO uma segunda descoberta DEVE ser rejeitada sem sobrescrever silenciosamente, reaproveitando a validação de conflito já existente em `OApiPath`/`OApiDoc`.
3. **ADPT-09:** QUANDO `title`/`description` estiverem presentes na annotation ENTÃO eles DEVEM alimentar a operação; quando ausentes, a operação DEVE permanecer válida com um valor default documentado.

### P3: Extrair parâmetros e body disponíveis

**História:** Como consumidor do documento gerado, quero que os parâmetros de path, query e o request body apareçam sem precisar ser redigitados manualmente.

1. **ADPT-10:** QUANDO o endpoint contiver segmentos `:nome` ENTÃO o adaptador DEVE gerar um `OApiParam` de path obrigatório para cada um, na ordem em que aparecem no texto do endpoint.
2. **ADPT-11:** QUANDO houver metadados de parâmetros adicionais (query/header) acessíveis pelo mecanismo confirmado no spike ENTÃO o adaptador DEVE gerá-los como `OApiParam`; quando o mecanismo não permitir extrair esse dado automaticamente, o adaptador DEVE expor uma forma complementar declarativa (annotation própria ou função companheira), nunca inventar um valor não declarado.
3. **ADPT-12:** QUANDO houver um request body identificável pelo mesmo mecanismo (ou pela forma complementar) ENTÃO o adaptador DEVE gerar um `OApiBody` associado à operação.

### P4: Montar o documento automaticamente

**História:** Como mantenedor, quero que o documento produzido pelo adaptador seja equivalente ao que hoje é montado manualmente, sem exigir edição paralela em dois lugares.

1. **ADPT-13:** QUANDO o adaptador terminar de processar os dois exemplos-alvo ENTÃO o `OApiDoc` resultante DEVE ser estruturalmente equivalente ao documento hoje montado manualmente em `examples/openapi-core/custom.openapi.core.api.tlpp` para essas duas operações (mesmos paths, verbos e parâmetros).
2. **ADPT-14:** QUANDO o processamento encontrar uma annotation malformada, incompleta ou com atributo em formato inesperado ENTÃO o adaptador DEVE acumular uma pendência com contexto (arquivo, função, atributo) e nunca produzir um path ou parâmetro incorreto silenciosamente.

### P5: Documentar limitações de inferência

**História:** Como leitor do projeto, quero saber exatamente o que o adaptador consegue e não consegue inferir sozinho.

1. **ADPT-15:** QUANDO o incremento for concluído ENTÃO o projeto DEVE documentar explicitamente o que não é derivável automaticamente (reflection em métodos de classe, tipos de retorno, parâmetros formais da função, rotas dinâmicas via `sLoadURNs`) e quais annotations ou funções complementares foram definidas para cobrir essas lacunas.

## Casos-limite

- Função anotada sem o atributo `endpoint` (forma mínima só com string posicional vs. forma nomeada) — o adaptador deve reconhecer as duas sintaxes confirmadas em `custom.openapi.hello.get.tlpp`/`.post.tlpp`.
- Endpoint com múltiplos segmentos `:nome` (path aninhado).
- Annotation presente mas função não compilada/não carregada no RPO no momento da descoberta.
- Duas funções distintas anotadas com o mesmo endpoint e verbo (conflito real a ser rejeitado, não silenciado).
- Atributo `responses` presente mas com JSON malformado — deve virar pendência, não exceção não tratada nem schema incorreto.
- A API de reflection (se confirmada) pode não devolver os atributos na mesma ordem declarada no código-fonte — o adaptador não deve assumir ordem além da que o endpoint já garante para path params.

## Rastreabilidade

| Requisitos | Componente planejado | Estado |
| --- | --- | --- |
| ADPT-01 a ADPT-03 | spike de verificação (T1) | **Confirmado por evidência real** (compilação + HTTP) em 2026-09-25 |
| ADPT-04 a ADPT-06, ADPT-09 | `OApiAdpDsc::discover()` (T2) | **Implementado e validado** (PROBAT, compilação) em 2026-09-25 |
| ADPT-07, ADPT-10 | `OApiAdpPath::toTemplate()`/`toParams()` (T3) | **Implementado e validado** (PROBAT, compilação) em 2026-09-25 |
| ADPT-08 | validação de conflito do núcleo (`OApiDoc::addPath`, reaproveitada em `OApiAdpBuild`) | **Implementado e validado** em 2026-09-25 |
| ADPT-11, ADPT-12 | `OApiAdpMeta::toQueryParams()`/`toBody()`/`toResponses()` (T4/T5) | **Implementado e validado** (PROBAT, compilação) em 2026-09-25 |
| ADPT-13 a ADPT-14 | `OApiAdpBuild::build()` (T5) | **Implementado e validado** (PROBAT, compilação) em 2026-09-25 |
| ADPT-15 | documentação de limitações (T6) | **Concluído** em 2026-09-25 |

**Cobertura:** 15/15 requisitos implementados e validados por evidência real (compilação + PROBAT), 0 não mapeados. Ver `design.md` para a API exata e `docs/experiments/openapi-tlpp-adapter.md` para as evidências e a lista de limitações deliberadas.

## Critérios de sucesso

- [x] Spike executado com compilação e execução reais no `P12_2510`, com evidência registrada — mecanismo confirmado (`Reflection.getFunctionsByAnnotation`/`isAnnotationFunctionPresent`/`getFunctionAnnotation`, 3 argumentos, retorno `Json`).
- [x] Adaptador reconhece `HeloGet` e `HeloPost` e monta `OApiPath`/`OApiOper`/`OApiParam`/`OApiBody` equivalentes ao documento manual atual (`OApiAdpBuild::build()`, validado via PROBAT em 2026-09-25).
- [x] O bug de path da sessão anterior (path divergente do texto anotado) é estruturalmente impossível no novo fluxo — o path do `OApiPath` é sempre uma transformação determinística do `endpoint` descoberto, nunca redigitado em outro lugar.
- [x] PROBAT cobre reconhecimento de verbo, extração de path/parâmetros, conflitos e pendências (cerca de 31 asserções, ver `docs/experiments/openapi-tlpp-adapter.md`).
- [x] Limitações de inferência documentadas no README/diário técnico.
