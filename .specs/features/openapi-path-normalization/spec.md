# Normalização segura de paths OpenAPI - Especificação

## Problema

O TLPPCore `01.06.01` gerou um YAML OpenAPI com 232 declarações para 226 paths únicos. Cinco paths padrão foram repetidos para separar operações HTTP, tornando inválido o documento completo e impedindo seu consumo por ferramentas OpenAPI convencionais.

## Objetivos

- [ ] Consolidar automaticamente apenas paths duplicados sem ambiguidades.
- [ ] Rejeitar conflitos sem escolher ou descartar conteúdo silenciosamente.
- [ ] Preservar o YAML bruto e produzir um novo arquivo válido em UTF-8 sem BOM.
- [ ] Executar sem módulos ou bibliotecas externas.
- [ ] Comprovar o comportamento com fixtures sanitizadas e com o YAML real ignorado pelo Git.

## Fora do escopo

| Item | Motivo |
| --- | --- |
| Modificar o TLPPCore ou o arquivo bruto | O artefato nativo deve permanecer como evidência reproduzível. |
| Documentar automaticamente endpoints `WSRESTFUL` | A ausência do endpoint AdvPL é uma lacuna distinta. |
| Resolver o mesmo verbo repetido | Não existe regra segura para escolher uma operação. |
| Corrigir schemas, referências ou conteúdo OpenAPI | A feature trata somente duplicidade estrutural em `paths`. |
| Versionar o YAML completo do ambiente | O documento contém catálogo interno de APIs. |
| Implementar a solução definitiva em TL++ | A primeira versão validará o algoritmo em PowerShell. |

## Histórias e critérios de aceitação

### P1: Consolidar paths sem ambiguidade

**História:** Como mantenedor da documentação, quero consolidar paths repetidos que contenham operações distintas para obter um documento estruturalmente válido sem perder operações.

1. **NORM-01:** QUANDO a entrada estiver em UTF-8 ou CP1252 ENTÃO o normalizador DEVE interpretar seu conteúdo corretamente.
2. **NORM-02:** QUANDO um path ocorrer uma única vez ENTÃO seu bloco DEVE ser preservado semanticamente.
3. **NORM-03:** QUANDO um path ocorrer mais de uma vez com verbos HTTP distintos ENTÃO os verbos DEVEM ser consolidados sob a primeira ocorrência do path.
4. **NORM-04:** QUANDO três ou mais ocorrências forem compatíveis ENTÃO todas as operações DEVEM ser mantidas na ordem original.
5. **NORM-05:** QUANDO campos compartilhados forem estruturalmente idênticos ENTÃO apenas uma ocorrência DEVE ser mantida.
6. **NORM-06:** QUANDO a consolidação terminar ENTÃO a saída NÃO DEVE conter chaves de path duplicadas.

**Teste independente:** normalizar fixtures com duas e três ocorrências compatíveis e validar a presença de todas as operações sob um único path.

### P1: Rejeitar consolidações inseguras

**História:** Como mantenedor, quero que ambiguidades interrompam a geração para impedir perda ou sobrescrita silenciosa de documentação.

1. **NORM-07:** QUANDO o mesmo verbo aparecer novamente no mesmo path ENTÃO o processamento DEVE falhar informando path, verbo e linhas.
2. **NORM-08:** QUANDO campos compartilhados forem incompatíveis ENTÃO o processamento DEVE falhar informando campo, path e linhas.
3. **NORM-09:** QUANDO a seção `paths` estiver ausente, duplicada ou estruturalmente inválida ENTÃO o processamento DEVE falhar com diagnóstico objetivo.
4. **NORM-10:** QUANDO qualquer validação falhar ENTÃO nenhum arquivo parcial DEVE permanecer no destino.

**Teste independente:** executar fixtures conflitantes e comprovar código de saída diferente de zero, mensagem diagnóstica e ausência do destino.

### P1: Preservar entrada e publicar saída controlada

**História:** Como operador, quero preservar o artefato bruto e controlar substituições para manter rastreabilidade e recuperação.

1. **NORM-11:** QUANDO entrada e saída resolverem para o mesmo caminho ENTÃO a execução DEVE ser rejeitada.
2. **NORM-12:** QUANDO o destino existir sem `-Force` ENTÃO a execução DEVE ser rejeitada sem alterar o arquivo existente.
3. **NORM-13:** QUANDO `-Force` for informado e a normalização for válida ENTÃO o destino DEVE ser substituído atomicamente.
4. **NORM-14:** QUANDO a saída for publicada ENTÃO ela DEVE estar em UTF-8 sem BOM.
5. **NORM-15:** QUANDO a execução terminar com sucesso ENTÃO um resumo DEVE informar declarações lidas, paths únicos, grupos consolidados e operações incorporadas.

**Teste independente:** verificar caminhos iguais, proteção do destino, substituição com `-Force`, encoding e resumo final.

## Casos-limite

- Linhas com tabulação na estrutura analisada devem ser rejeitadas.
- Comentários e seções fora de `paths` devem ser preservados.
- A comparação de paths e campos deve respeitar maiúsculas e minúsculas.
- Métodos OpenAPI reconhecidos são `get`, `put`, `post`, `delete`, `options`, `head`, `patch` e `trace`.
- Falhas durante a gravação devem remover somente o temporário criado pela própria execução.

## Rastreabilidade

| Requisito | História | Estado |
| --- | --- | --- |
| NORM-01 a NORM-06 | Consolidar paths | Em design |
| NORM-07 a NORM-10 | Rejeitar conflitos | Em design |
| NORM-11 a NORM-15 | Publicar saída | Em design |

**Cobertura:** 15 requisitos, 15 incluídos no design, 0 não mapeados.

## Critérios de sucesso

- [ ] Todas as fixtures válidas são normalizadas sem perda de operações.
- [ ] Todas as fixtures ambíguas são rejeitadas sem saída parcial.
- [ ] O YAML real passa de 232 declarações para 226 paths únicos.
- [ ] Os cinco grupos duplicados do ambiente são consolidados.
- [ ] O arquivo normalizado passa pela verificação estrutural existente.
- [ ] O YAML bruto permanece inalterado e fora do Git.

