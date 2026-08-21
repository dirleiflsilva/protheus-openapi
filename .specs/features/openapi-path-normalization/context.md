# Normalização de paths OpenAPI - Decisões

## Decisões confirmadas

| Tema | Decisão |
| --- | --- |
| Primeira implementação | PowerShell, antes de portar qualquer comportamento para TL++ |
| Dependências | nenhuma dependência externa |
| Arquivo bruto | nunca alterar |
| Entrada | YAML em CP1252 ou UTF-8 |
| Saída | caminho diferente da entrada, UTF-8 sem BOM e gravação atômica |
| Paths repetidos com verbos distintos | consolidar em uma única chave |
| Mesmo verbo repetido | interromper com erro, mesmo que os blocos pareçam iguais |
| Campos compartilhados idênticos | manter uma única ocorrência |
| Campos compartilhados incompatíveis | interromper com erro |
| Resolução automática de ambiguidades | proibida |
| Artefato real normalizado | manter fora do Git em `artifacts/local/` |

## Motivação

O objetivo inicial é validar as regras de normalização sobre o YAML real do TLPPCore com baixo custo operacional. A lógica somente poderá ser portada para a futura biblioteca depois que o comportamento estiver comprovado por fixtures sanitizadas e pelo artefato local do ambiente.

