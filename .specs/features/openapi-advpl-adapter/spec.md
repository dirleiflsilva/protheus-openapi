# Adaptador para endpoints AdvPL — Especificação

**Contexto:** `.specs/features/openapi-advpl-adapter/context.md`  
**Fase do roadmap:** Fase 4 — "Adaptador para AdvPL"  
**Prefixo de requisitos:** `ADVP`

---

## Problema

O adaptador TL++ (Fase 3) descobre endpoints em **runtime** via reflection sobre o RPO compilado. Endpoints `WSRESTFUL` em AdvPL são definidos por uma estrutura **sintática** expandida pelo pré-processador — não existe API de reflection equivalente para enumerá-los em runtime (confirmado por grep nas fontes padrão do Protheus).

Para produzir documentação OpenAPI de APIs AdvPL legadas ou customizadas, é necessário um adaptador diferente: um **parser de texto-fonte** capaz de extrair do bloco `WSRESTFUL ... END WSRESTFUL` as mesmas informações que a Fase 3 extrai via reflection (serviço, verbo, path, descrição, parâmetros), e de montar o mesmo modelo intermediário `OApiDoc` sem qualquer modificação nas classes do núcleo.

## Objetivos

- [ ] Parsear o bloco de definição `WSRESTFUL ... END WSRESTFUL` de um arquivo `.prw`/`.prg` fornecido como texto.
- [ ] Extrair serviço (`WSRESTFUL <nome>`), descrição (`DESCRIPTION`), parâmetros declarados (`WSDATA`) e operações (`WSMETHOD` + `DESCRIPTION` + `PATH`).
- [ ] Inferir `in: path` vs `in: query` para cada `WSDATA` a partir do template `PATH` de cada operação.
- [ ] Montar `OApiPath`/`OApiOper`/`OApiParam` usando a API pública do núcleo, sem alterá-lo.
- [ ] Comparar o resultado com o adaptador TL++ sobre operações equivalentes.
- [ ] Documentar limitações de inferência (PATH ausente, DESCRIPTION constante simbólica, tipos não-primitivos, bloco de implementação).

## Fora do escopo

| Item | Motivo |
|------|---------|
| Enumeração runtime de serviços WSRESTFUL | Inexistente na plataforma (confirmado). |
| Parsing do bloco de implementação `WSMETHOD ... WSSERVICE` | Mais complexo; parâmetros complementares (`PATHPARAM`/`QUERYPARAM`) enriquecem mas não são necessários para o escopo desta fase. |
| Descoberta automática em diretórios (múltiplos arquivos) | Esta fase cobre um arquivo-fonte por chamada. |
| Suporte a PATH ausente como caso principal | Forma mais antiga; PATH absoluto é o escopo. PATH ausente é documentado como limitação. |
| PATH relativo (fragmento) como caso principal | Documentado como limitação. |
| Substituição de constantes simbólicas (STR0001) | Sem acesso à tabela de strings do RPO; gera pendência documentada. |
| Alterações no núcleo `OApi*` | A Fase 4 consome o núcleo existente. |
| Adaptador TL++ (Fase 3) | Não é modificado. |
| Extrair código-fonte de RPO compilado | Vedado pelo README. |
| `RESPONSE EaiObj` e tipos não-primitivos como schema | Fora do escopo desta fase. |

---

## Histórias e critérios de aceitação

### P0: Confirmar a premissa de parsing textual (spike, pré-requisito)

**História:** Como mantenedor, quero confirmar com evidência real (compilação + execução no `P12_2510`) que ler e processar o texto-fonte de um `.prw` a partir de TL++ é viável, incluindo a leitura de arquivo e a extração de linhas relevantes via regex.

1. **ADVP-01:** QUANDO o spike for executado ENTÃO ele DEVE confirmar, com evidência de compilação real, que uma `User Function` TL++ consegue abrir e ler o conteúdo textual de um arquivo `.prw` no servidor AppServer.
2. **ADVP-02:** QUANDO o spike for executado ENTÃO ele DEVE confirmar que expressões regulares (`RegexMatch` ou equivalente TL++) conseguem identificar ao menos uma linha `WSRESTFUL <nome> DESCRIPTION` no texto do arquivo-alvo.
3. **ADVP-03:** QUANDO o spike revelar que a API de leitura de arquivo ou regex não está disponível ou tem limitação crítica ENTÃO o design do adaptador DEVE ser revisado antes de continuar, e essa limitação DEVE ser registrada explicitamente.

### P1: Parsear o bloco de definição WSRESTFUL

**História:** Como mantenedor, quero que o parser extraia corretamente o bloco de definição WSRESTFUL de um arquivo-fonte, tolerando variações de formatação reais encontradas nas fontes padrão.

4. **ADVP-04:** QUANDO o parser processar um arquivo ENTÃO ele DEVE reconhecer `WSRESTFUL <nome> DESCRIPTION <literal>` e extrair o nome do serviço e a descrição.
5. **ADVP-05:** QUANDO a DESCRIPTION for uma string literal entre aspas ou apóstrofos ENTÃO o valor DEVE ser extraído sem as aspas.
6. **ADVP-06:** QUANDO a DESCRIPTION for uma constante simbólica (ex.: `STR0001`) ENTÃO o parser DEVE registrar uma pendência com o nome da constante e usar `""` como valor, sem falhar.
7. **ADVP-07:** QUANDO o bloco for encerrado por `END WSRESTFUL` ou `ENDWSRESTFUL` (com ou sem espaço) ENTÃO o parser DEVE reconhecer os dois terminadores.
8. **ADVP-08:** QUANDO uma linha dentro do bloco usar continuação `;` (multilinha AdvPL) ENTÃO o parser DEVE unir as linhas antes de extrair tokens, produzindo o mesmo resultado que a versão de linha única.

### P2: Extrair WSDATA (parâmetros do serviço)

**História:** Como mantenedor, quero que o parser extraia os parâmetros declarados em WSDATA para poder associá-los às operações.

9. **ADVP-09:** QUANDO o parser encontrar `WSDATA <nome> AS <tipo>` ENTÃO ele DEVE extrair nome, tipo e flag opcional (`OPTIONAL`).
10. **ADVP-10:** QUANDO o tipo de WSDATA for `STRING` ou `CHARACTER` ENTÃO o schema gerado DEVE ter `type: string`.
11. **ADVP-11:** QUANDO o tipo de WSDATA for `INTEGER` ou `INT` ENTÃO o schema gerado DEVE ter `type: integer`.
12. **ADVP-12:** QUANDO o tipo de WSDATA for `BOOLEAN` ENTÃO o schema gerado DEVE ter `type: boolean`.
13. **ADVP-13:** QUANDO o tipo de WSDATA for `ARRAY` ou desconhecido ENTÃO o schema gerado DEVE ter `type: string` com uma pendência documentada registrada.

### P3: Extrair operações WSMETHOD

**História:** Como mantenedor, quero que o parser extraia cada operação definida no bloco WSRESTFUL com seu verbo, path e descrição.

14. **ADVP-14:** QUANDO o parser encontrar `WSMETHOD <VERBO> [<NomeAcao>]` dentro do bloco ENTÃO ele DEVE extrair o verbo HTTP e o nome de ação opcional.
15. **ADVP-15:** QUANDO a cláusula `PATH` estiver presente e não vazia ENTÃO o PATH DEVE ser a fonte primária para o caminho da operação — não o WSSYNTAX.
16. **ADVP-16:** QUANDO a cláusula `PATH` estiver ausente ou vazia ENTÃO o adaptador DEVE registrar uma pendência com contexto (serviço, método) e omitir a operação do documento (não gerar um path incorreto silenciosamente).
17. **ADVP-17:** QUANDO o `PATH` contiver segmentos `{nome}` ENTÃO o `OApiPath` resultante DEVE usar exatamente essa string (já no formato OpenAPI `{nome}`, sem conversão adicional).
18. **ADVP-18:** QUANDO duas operações produzirem o mesmo template de path ENTÃO elas DEVEM ser agrupadas sob o mesmo `OApiPath`, da mesma forma que o adaptador TL++ agrupa operações antes de chamar `OApiDoc::addPath()`.
19. **ADVP-19:** QUANDO `DESCRIPTION` da operação for uma string literal ENTÃO ela DEVE alimentar a `OApiOper`; quando ausente ou constante simbólica, DEVE usar `""` com pendência.

### P4: Inferir localização dos parâmetros (in: path vs in: query)

**História:** Como consumidor do documento gerado, quero que os parâmetros apareçam com a localização correta (path ou query) sem exigir metadados complementares manuais.

20. **ADVP-20:** QUANDO um `WSDATA` tiver seu nome entre `{...}` no `PATH` da operação ENTÃO o `OApiParam` correspondente DEVE ter `in: path` e `required: true`.
21. **ADVP-21:** QUANDO um `WSDATA` não aparecer entre `{...}` no `PATH` de nenhuma operação ENTÃO o `OApiParam` correspondente DEVE ter `in: query` e `required` igual ao oposto de `OPTIONAL`.
22. **ADVP-22:** QUANDO a mesma variável `WSDATA` aparecer no `PATH` de uma operação e não no `PATH` de outra ENTÃO ela DEVE ser gerada como `in: path` na primeira e `in: query` na segunda.

### P5: Montar o documento OpenAPI

**História:** Como mantenedor, quero que o adaptador produza um `OApiDoc` estruturalmente correto usando a API pública do núcleo, reutilizável como entrada para o `OApiJson`.

23. **ADVP-23:** QUANDO o adaptador processar o exemplo-alvo (`examples/openapi-advpl-adapter/hello-advpl.prw`) ENTÃO o `OApiDoc` resultante DEVE conter os paths e operações equivalentes ao que seria montado manualmente para esse arquivo.
24. **ADVP-24:** QUANDO `oDoc:validate()` for chamado após a montagem ENTÃO DEVE retornar zero pendências para o exemplo-alvo (paths válidos, operações válidas, sem requisitos violados).
25. **ADVP-25:** QUANDO o processamento encontrar uma linha malformada, incompleta ou com token inesperado ENTÃO o adaptador DEVE acumular uma pendência com contexto (arquivo, serviço, linha aproximada) e nunca produzir um path ou parâmetro incorreto silenciosamente.
26. **ADVP-26:** QUANDO path+verbo duplicado for detectado ENTÃO a validação do núcleo (`OApiDoc::addPath()`) DEVE rejeitar o conflito sem sobrescrever silenciosamente.

### P6: Comparar com o adaptador TL++ (Fase 3)

**História:** Como leitor do projeto, quero entender objetivamente o que o adaptador AdvPL consegue e não consegue inferir em relação ao adaptador TL++.

27. **ADVP-27:** QUANDO o incremento for concluído ENTÃO o projeto DEVE documentar uma comparação objetiva entre os dois adaptadores: o que o adaptador AdvPL consegue extrair do bloco de definição, o que só é acessível via reflection TL++, e quais lacunas existem no `WSRESTFUL` em relação às annotations.

---

## Casos-limite

- Arquivo sem nenhum bloco `WSRESTFUL` — o parser deve retornar resultado vazio sem falhar.
- Múltiplos blocos `WSRESTFUL` no mesmo arquivo (incomum mas possível) — o parser deve processar todos.
- `WSMETHOD` com mesmo verbo e nome de ação repetido no mesmo serviço — deve virar pendência.
- `WSDATA` declarado mas não referenciado em nenhuma operação (parâmetro não usado) — gera `OApiParam in: query` com `required: false`.
- Linha em branco ou só comentário dentro do bloco de definição — ignorada sem erro.
- `DESCRIPTION` com string vazia explícita (`""`) — aceita como valor, sem pendência.
- `PATH` com espaços ou aspas extras — normalizar (trim + remover aspas antes de usar).

---

## Rastreabilidade

| Requisito | Componente planejado | Estado |
|-----------|---------------------|--------|
| ADVP-01 a ADVP-03 | spike de leitura de arquivo + regex (T1) | Planejado |
| ADVP-04 a ADVP-08 | `OApiAdpWsr::parse()` — reconhecimento do bloco (T2) | Planejado |
| ADVP-09 a ADVP-13 | `OApiAdpWsr::parse()` — extração de WSDATA (T2/T3) | Planejado |
| ADVP-14 a ADVP-19 | `OApiAdpWsr::parse()` — extração de WSMETHOD (T3) | Planejado |
| ADVP-20 a ADVP-22 | `OApiAdpWsPath` — inferência de localização de parâmetro (T4) | Planejado |
| ADVP-23 a ADVP-26 | `OApiAdpWsBuild::build()` — montagem do OApiDoc (T5) | Planejado |
| ADVP-27 | diário técnico + documentação comparativa (T6) | Planejado |

## Critérios de sucesso

- [ ] Spike executado com compilação e execução reais no `P12_2510`, confirmando leitura de arquivo e regex em TL++.
- [ ] Adaptador parseia `examples/openapi-advpl-adapter/hello-advpl.prw` e produz `OApiDoc` equivalente ao documento montado manualmente para esse arquivo.
- [ ] `oDoc:validate()` retorna zero pendências sobre o exemplo-alvo.
- [ ] PROBAT cobre reconhecimento de bloco, extração de WSDATA, inferência de parâmetros e conflitos (mínimo 20 asserções).
- [ ] Limitações documentadas: PATH ausente, constantes simbólicas, bloco de implementação, tipos não-primitivos.
- [ ] Comparação com adaptador TL++ documentada no diário técnico.
