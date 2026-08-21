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

Validar a publicação de um endpoint TL++ por annotation, sua documentação nativa e a exportação do documento OpenAPI em YAML.

## Resultados

| Verificação | Estado |
| --- | --- |
| Compilação dos fontes TL++ no RPO REST | concluída para os dois fontes em 2026-08-21. |
| Execução de `GET /api/v1/hello` | HTTP `401` sem credenciais e HTTP `200` com autenticação. |
| Corpo e cabeçalhos retornados pelo Hello World | `application/json`; corpo esperado confirmado. |
| Exportação com `tlpp.doc.generate()` | concluída em modo `swagger`; arquivo YAML criado. |
| Versão declarada no documento | OpenAPI `3.0.3`. |
| Path efetivamente gerado | `/api/v1/hello`, com `GET`, summary, descrição e resposta `200` esperados. |
| Localização do artefato bruto | `D:\TOTVS12\Protheus12_2510\protheus_data\system\hello_openapi_8084.yaml`. |
| Validação e extração do snapshot sanitizado | fragmento Hello World válido; documento completo rejeitado por paths duplicados; extração pendente. |
| Visualização da documentação nativa | VS Code identificou seis ocorrências de chaves YAML duplicadas em cinco paths padrão. |

O endpoint autenticado retornou exatamente `{"message":"Hello World","language":"TL++","status":"success"}`. O acionador de exportação também retornou HTTP `200`.

## Diagnóstico do primeiro artefato

O console confirmou o início e o encerramento do REST-DOC, mas registrou `O conteudo JSON com documentacao e invalido.` para diversas rotas, inclusive as duas rotas do experimento. O arquivo produzido em modo `json` não era uma especificação OpenAPI: tratava-se da representação interna do REST-DOC e continha valores JSON aninhados sem escape, como o campo `responses`.

As referências oficiais do TLPPCore usam o formato `swagger` para produzir o documento OpenAPI em `.yaml` e reservam `json` para a representação bruta. Por isso, o fonte foi corrigido para:

```tlpp
tlpp.doc.generate("swagger", "hello_openapi", {8084}, {"pt-br"})
```

A correção foi recompilada e executada. O arquivo resultante confirmou o OpenAPI `3.0.3` e incluiu corretamente as duas rotas do experimento.

## Diagnóstico do YAML OpenAPI

O gerador reuniu 232 declarações de path, correspondentes a 226 paths únicos. Cinco paths padrão dos módulos Fiscal e TAF foram emitidos mais de uma vez, separando verbos HTTP sob chaves YAML iguais. Um desses paths apareceu três vezes; por isso, o VS Code apresentou seis diagnósticos `Map keys must be unique`.

As rotas `/api/v1/hello` e `/api/v1/openapi/export` aparecem uma vez cada e seus metadados foram gerados corretamente. Entretanto, as duplicidades tornam inválido o documento completo. O validador local passou a rejeitar qualquer YAML com paths duplicados e a informar as chaves e linhas conflitantes.

O arquivo nativo também foi gravado em Windows-1252. Essa característica afeta a exibição dos acentos quando o arquivo é aberto como UTF-8, mas não causa as duplicidades.

## Segurança dos artefatos

O documento bruto completo deve permanecer em `artifacts/local/`, diretório ignorado pelo Git. Somente o snapshot JSON sanitizado da operação Hello World poderá ser incluído no repositório, após inspeção para remover dados de ambiente, autenticação e outras informações sensíveis.

Não registrar credenciais, cabeçalhos de autorização nem configurações completas do AppServer neste diário.

## Limitações observadas

- Execução no AppServer: confirmada para as duas compilações.
- Compatibilidade efetiva das annotations com o ambiente informado: endpoint e metadados do experimento foram descobertos e exportados.
- Formato e versão produzidos pelo gerador nativo em modo `swagger`: YAML OpenAPI `3.0.3` em Windows-1252.
- Prefixo real do path e endereço da interface de documentação: pendente.
- Diretório de saída escolhido pelo TLPPCore: confirmado como `protheus_data\system`.
- Documento completo: inválido devido a cinco paths padrão duplicados; o problema não pertence às rotas do experimento.

## Roteiro operacional

1. Executar os contratos locais de [`hello-api.tlpp`](../../examples/hello-world/hello-api.tlpp) e [`openapi-export.tlpp`](../../examples/hello-world/openapi-export.tlpp):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
   ```

2. Recompilar `openapi-export.tlpp` no RPO REST do ambiente `P12_2510` e registrar o resultado apresentado pela ferramenta.
3. Chamar novamente o endpoint de exportação usando autenticação fornecida apenas no cliente HTTP; registrar somente status, cabeçalhos relevantes e corpo não sensível.
4. Localizar o YAML gerado, copiá-lo como `artifacts/local/hello-openapi.yaml` e validá-lo informando o parâmetro obrigatório `-Path`:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path artifacts/local/hello-openapi.yaml
   ```

5. Gerar o snapshot mínimo informando os parâmetros obrigatórios `-InputPath` e `-OutputPath`; depois, inspecionar e validar o arquivo resultante:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-hello-openapi.ps1 -InputPath artifacts/local/hello-openapi.yaml -OutputPath examples/hello-world/snapshots/hello-openapi.json
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path examples/hello-world/snapshots/hello-openapi.json
   ```

6. Abrir a documentação nativa, localizar `GET /api/v1/hello` e registrar a versão, o path, a resposta documentada e eventuais limitações.
