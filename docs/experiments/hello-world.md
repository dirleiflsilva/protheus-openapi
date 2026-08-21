# Experimento Hello World com REST-DOC

## Ambiente

| Componente | Versão |
| --- | --- |
| Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 (build 7.00.240223P) |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 - TLPP PANTHERA ONCA |
| REST | `http://localhost:8084/rest` |

## Objetivo

Validar a publicação de endpoints equivalentes em TL++ e AdvPL, comparar sua descoberta documental nativa e exportar o documento OpenAPI em YAML.

## Resultados

| Verificação | Estado |
| --- | --- |
| Compilação dos fontes TL++ no RPO REST | concluída para os dois fontes em 2026-08-21. |
| Execução de `GET /api/v1/hello` | HTTP `401` sem credenciais e HTTP `200` com autenticação. |
| Corpo e cabeçalhos retornados pelo Hello World | `application/json`; corpo esperado confirmado. |
| Compilação do fonte AdvPL no RPO REST | concluída sem erros em 2026-08-21 às 15:27:43. |
| Execução de `GET /api/v1/hello-advpl` | HTTP `401` sem credenciais e HTTP `200` com autenticação. |
| Corpo retornado pelo Hello World AdvPL | `{"message":"Hello World","language":"AdvPL","status":"success"}`. |
| Exportação com `tlpp.doc.generate()` | concluída em modo `swagger`; arquivo YAML criado. |
| Nova exportação após publicar o endpoint AdvPL | concluída em 2026-08-21 às 15:36:11; arquivo com 54.260 bytes. |
| Versão declarada no documento | OpenAPI `3.0.3`. |
| Path efetivamente gerado | `/api/v1/hello`, com `GET`, summary, descrição e resposta `200` esperados. |
| Descoberta do path AdvPL | `/api/v1/hello-advpl` não foi emitido no YAML nativo. |
| Localização do artefato bruto | `D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml`. |
| Normalização do documento completo | 232 declarações consolidadas em 226 paths únicos; cinco grupos e seis operações incorporadas. |
| Validação do YAML normalizado | OpenAPI `3.0.3` aceito pelo validador do experimento; saída UTF-8 sem BOM. |
| Visualização da documentação nativa | VS Code identificou seis ocorrências de chaves YAML duplicadas em cinco paths padrão. |

O endpoint autenticado retornou exatamente `{"message":"Hello World","language":"TL++","status":"success"}`. O acionador de exportação também retornou HTTP `200`.

## Diagnóstico do primeiro artefato

O console confirmou o início e o encerramento do REST-DOC, mas registrou `O conteudo JSON com documentacao e invalido.` para diversas rotas, inclusive as duas rotas do experimento. O arquivo produzido em modo `json` não era uma especificação OpenAPI: tratava-se da representação interna do REST-DOC e continha valores JSON aninhados sem escape, como o campo `responses`.

As referências oficiais do TLPPCore usam o formato `swagger` para produzir o documento OpenAPI em `.yaml` e reservam `json` para a representação bruta. Por isso, o fonte foi corrigido para:

```tlpp
tlpp.doc.generate("swagger", "hello_openapi", {8084}, {"pt-br"})
```

A correção foi recompilada e executada. O arquivo resultante confirmou o OpenAPI `3.0.3` e incluiu corretamente as duas rotas TL++ do experimento: o Hello World e o acionador de exportação.

## Diagnóstico do YAML OpenAPI

O gerador reuniu 232 declarações de path, correspondentes a 226 paths únicos. Cinco paths padrão dos módulos Fiscal e TAF foram emitidos mais de uma vez, separando verbos HTTP sob chaves YAML iguais. Um desses paths apareceu três vezes; por isso, o VS Code apresentou seis diagnósticos `Map keys must be unique`.

As rotas `/api/v1/hello` e `/api/v1/openapi/export` aparecem uma vez cada e seus metadados foram gerados corretamente. Entretanto, as duplicidades tornam inválido o documento completo. O validador local passou a rejeitar qualquer YAML com paths duplicados e a informar as chaves e linhas conflitantes.

O arquivo nativo também foi gravado em Windows-1252. Essa característica afeta a exibição dos acentos quando o arquivo é aberto como UTF-8, mas não causa as duplicidades.

## Normalização segura do YAML completo

O script `scripts/normalize-openapi-paths.ps1` foi implementado sem dependências externas para consolidar apenas duplicidades sem ambiguidades. Paths repetidos com verbos HTTP distintos são unidos; o mesmo verbo repetido ou campos compartilhados incompatíveis interrompem a execução com diagnóstico de path, chave e linhas.

A execução sobre o artefato real apresentou:

| Medida | Resultado |
| --- | --- |
| Declarações de path lidas | 232 |
| Paths únicos publicados | 226 |
| Grupos duplicados consolidados | 5 |
| Operações incorporadas | 6 |
| Versão validada | OpenAPI `3.0.3` |
| Encoding da saída | UTF-8 sem BOM |
| Testes automatizados | 15 aprovados, 0 falhas |

O arquivo bruto permaneceu com 54.260 bytes, data `2026-08-21 15:36:11` e SHA-256 `51998A70AAC61EE782E233033FD2A5A607DCF693F7C0CAF9F4321F9301F3467E` antes e depois do processamento. O resultado foi gravado como `artifacts/local/hello-openapi-normalized.yaml`, caminho ignorado pelo Git.

A normalização corrige a estrutura agregada dos paths, mas deliberadamente não cria a operação AdvPL ausente. A complementação documental de endpoints `WSRESTFUL` permanece como uma feature posterior.

## Evidência comparativa TL++ e AdvPL

Após a compilação e publicação do `WSRESTFUL`, o endpoint AdvPL respondeu corretamente em runtime. Uma nova execução autenticada do exportador retornou HTTP `200`, e o arquivo `hello_openapi_8084.yaml` foi atualizado em 2026-08-21 às 15:36:11. A busca direcionada no novo artefato não encontrou `/api/v1/hello-advpl`, `HloAdv`, `Hello World AdvPL` nem outro marcador do endpoint AdvPL.

O resultado demonstra que, neste ambiente com TLPPCore `01.06.01`, `tlpp.doc.generate()` descobriu o endpoint TL++ baseado em annotation, mas não emitiu documentação para o endpoint AdvPL baseado em `WSRESTFUL`. A ausência foi registrada como resultado observado; não foram inventados metadados para representar uma operação que não existe no YAML nativo.

| Aspecto | TL++ com annotation | AdvPL com `WSRESTFUL` |
| --- | --- | --- |
| Endpoint funcional | sim | sim |
| Segurança herdada de `SECURITY=1` | HTTP `401` sem autenticação | HTTP `401` sem autenticação |
| Resposta autenticada | HTTP `200`, JSON esperado | HTTP `200`, JSON esperado |
| Descoberta por `tlpp.doc.generate()` | sim | não observada |
| Path no YAML | `/api/v1/hello` | ausente |
| Verbo no YAML | `get` | ausente |
| Resumo no YAML | `Hello World` | ausente |
| Descrição no YAML | emitida | ausente |
| Resposta `200` no YAML | emitida | ausente |
| Metadados declarados no fonte | annotation `@Get` | `DESCRIPTION`, `WSSYNTAX`, `PATH` e `PRODUCES` |

Essa lacuna delimita uma responsabilidade provável da futura biblioteca: complementar ou produzir documentação para serviços `WSRESTFUL`, sem alterar seu comportamento de runtime.

## Segurança dos artefatos

O documento bruto completo deve permanecer em `artifacts/local/`, diretório ignorado pelo Git. Somente o snapshot JSON sanitizado da operação Hello World poderá ser incluído no repositório, após inspeção para remover dados de ambiente, autenticação e outras informações sensíveis.

Não registrar credenciais, cabeçalhos de autorização nem configurações completas do AppServer neste diário.

## Limitações observadas

- Execução no AppServer: confirmada para as duas compilações.
- Compatibilidade efetiva das annotations com o ambiente informado: endpoint e metadados do experimento foram descobertos e exportados.
- Formato e versão produzidos pelo gerador nativo em modo `swagger`: YAML OpenAPI `3.0.3` em Windows-1252.
- Prefixo real do path e endereço da interface de documentação: pendente.
- Diretório de saída escolhido pelo TLPPCore: confirmado como `protheus_data\system`.
- Documento bruto: inválido devido a cinco paths padrão duplicados; o problema não pertence às rotas do experimento.
- Documento normalizado: estruturalmente válido para o experimento, com os cinco grupos consolidados sem conflito.

## Roteiro operacional

1. Executar os contratos locais de [`hello-api.tlpp`](../../examples/hello-world/hello-api.tlpp) e [`openapi-export.tlpp`](../../examples/hello-world/openapi-export.tlpp):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
   ```

2. Recompilar `openapi-export.tlpp` no RPO REST do ambiente `P12_2510` e registrar o resultado apresentado pela ferramenta.
3. Chamar novamente o endpoint de exportação usando autenticação fornecida apenas no cliente HTTP; registrar somente status, cabeçalhos relevantes e corpo não sensível.
4. Normalizar o YAML bruto para um artefato local ignorado pelo Git:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/normalize-openapi-paths.ps1 -InputPath D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml -OutputPath artifacts/local/hello-openapi-normalized.yaml -Force
   ```

5. Validar o YAML normalizado:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path artifacts/local/hello-openapi-normalized.yaml
   ```

6. Quando necessário, gerar o snapshot mínimo a partir do documento normalizado; depois, inspecionar e validar o arquivo resultante:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-hello-openapi.ps1 -InputPath artifacts/local/hello-openapi-normalized.yaml -OutputPath examples/hello-world/snapshots/hello-openapi.json
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path examples/hello-world/snapshots/hello-openapi.json
   ```

7. Abrir a documentação normalizada, localizar `GET /api/v1/hello` e registrar a versão, o path, a resposta documentada e eventuais limitações.
