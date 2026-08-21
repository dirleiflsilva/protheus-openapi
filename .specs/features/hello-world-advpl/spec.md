# Hello World AdvPL - Especificação

## Problema

A prova de conceito TL++ confirmou a publicação REST e a geração nativa de OpenAPI, mas ainda não existe uma referência equivalente em AdvPL. Sem essa comparação, não é possível delimitar quais metadados a futura biblioteca precisará complementar para fontes `WSRESTFUL`.

## Objetivos

- [ ] Publicar um Hello World AdvPL autenticado em `GET /api/v1/hello-advpl`.
- [ ] Retornar o mesmo contrato funcional do exemplo TL++, alterando apenas `language` para `AdvPL`.
- [ ] Observar como `WSRESTFUL` aparece no YAML OpenAPI nativo.
- [ ] Registrar uma matriz comparativa entre TL++ e AdvPL.

## Fora do escopo

| Item | Motivo |
| --- | --- |
| Acesso a tabelas, parâmetros ou dicionário | O experimento deve isolar o comportamento REST e documental. |
| Tornar a rota pública | A configuração `SECURITY=1` deve ser preservada. |
| Parâmetros de path, query ou body | Serão avaliados nas fases posteriores do roadmap. |
| Corrigir os paths padrão duplicados pelo TLPPCore | A falha pertence ao documento agregado da porta e não ao endpoint experimental. |
| Implementar o núcleo da biblioteca OpenAPI | Esta feature encerra somente a pesquisa comparativa da Fase 0. |

## Histórias e critérios de aceitação

### P1: Executar o Hello World AdvPL

**História:** Como desenvolvedor Protheus, quero executar um endpoint mínimo em AdvPL para compará-lo objetivamente ao endpoint TL++.

1. **ADVH-01:** QUANDO o fonte for compilado no RPO REST ENTÃO a compilação DEVE terminar sem erros.
2. **ADVH-02:** QUANDO a rota for chamada sem autenticação ENTÃO o servidor DEVE preservar o bloqueio HTTP `401` do ambiente.
3. **ADVH-03:** QUANDO a rota for chamada com autenticação válida ENTÃO o servidor DEVE responder HTTP `200` e `Content-Type: application/json`.
4. **ADVH-04:** QUANDO a resposta for interpretada ENTÃO ela DEVE conter exatamente `message=Hello World`, `language=AdvPL` e `status=success`.

**Teste independente:** compilar o fonte e executar as chamadas autenticada e não autenticada com `curl.exe`.

### P1: Comparar a documentação nativa

**História:** Como mantenedor da futura biblioteca, quero observar os metadados gerados para `WSRESTFUL` para identificar lacunas em relação às annotations TL++.

1. **ADVH-05:** QUANDO o REST-DOC for executado novamente ENTÃO o YAML DEVE conter uma operação correspondente a `/api/v1/hello-advpl`.
2. **ADVH-06:** QUANDO a operação for inspecionada ENTÃO verbo, path, descrição e respostas observadas DEVEM ser registrados sem completar informações ausentes por suposição.
3. **ADVH-07:** QUANDO TL++ e AdvPL forem comparados ENTÃO uma matriz DEVE indicar metadados presentes, ausentes e limitações de cada mecanismo.
4. **ADVH-08:** QUANDO o artefato agregado contiver paths duplicados ENTÃO essa limitação DEVE permanecer separada do resultado específico do endpoint AdvPL.

**Teste independente:** gerar o YAML, localizar somente o path AdvPL e confrontar seus campos com o path TL++.

## Rastreabilidade

| Requisito | Prioridade | Fase | Estado |
| --- | --- | --- | --- |
| ADVH-01 | P1 | Implementação | Pendente |
| ADVH-02 | P1 | Runtime | Pendente |
| ADVH-03 | P1 | Runtime | Pendente |
| ADVH-04 | P1 | Runtime | Pendente |
| ADVH-05 | P1 | Runtime | Pendente |
| ADVH-06 | P1 | Análise | Pendente |
| ADVH-07 | P1 | Documentação | Pendente |
| ADVH-08 | P1 | Análise | Pendente |

## Critérios de sucesso

- [ ] Fonte AdvPL em Windows-1252 sem BOM e com ProtheusDOC.
- [ ] Contrato estático e compilação aprovados.
- [ ] Comportamento HTTP comprovado no ambiente `P12_2510`.
- [ ] Path AdvPL localizado no documento nativo.
- [ ] Matriz comparativa publicada sem incluir o YAML bruto do ambiente.
