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

Validar a publicação de um endpoint TL++ por annotation, sua documentação nativa e a exportação do documento OpenAPI em JSON.

## Resultados

| Verificação | Estado |
| --- | --- |
| Compilação dos fontes TL++ no RPO REST | pendente. |
| Execução de `GET /api/v1/hello` | pendente. |
| Corpo e cabeçalhos retornados pelo Hello World | pendente. |
| Exportação com `tlpp.doc.generate()` | pendente. |
| Versão declarada no documento | pendente. |
| Path efetivamente gerado | pendente. |
| Localização do JSON bruto | pendente. |
| Validação e extração do snapshot sanitizado | pendente. |
| Visualização da documentação nativa | pendente. |

Nenhuma compilação, chamada HTTP ou geração do documento foi executada nesta etapa.

## Segurança dos artefatos

O documento bruto completo deve permanecer em `artifacts/local/`, diretório ignorado pelo Git. Somente o snapshot sanitizado da operação Hello World poderá ser incluído no repositório, após inspeção para remover dados de ambiente, autenticação e outras informações sensíveis.

Não registrar credenciais, cabeçalhos de autorização nem configurações completas do AppServer neste diário.

## Limitações observadas

- Execução no AppServer: pendente.
- Compatibilidade efetiva das annotations com o ambiente informado: pendente.
- Formato e versão produzidos pelo gerador nativo: pendente.
- Prefixo real do path e endereço da interface de documentação: pendente.
- Diretório de saída escolhido pelo TLPPCore: pendente.

## Roteiro operacional

1. Executar os contratos locais de [`hello-api.tlpp`](../../examples/hello-world/hello-api.tlpp) e [`openapi-export.tlpp`](../../examples/hello-world/openapi-export.tlpp):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target hello
   powershell -NoProfile -ExecutionPolicy Bypass -File tests/hello-world/validate-sources.ps1 -Target export
   ```

2. Compilar os dois fontes no RPO REST do ambiente `P12_2510` e registrar separadamente o resultado apresentado pela ferramenta.
3. Chamar o endpoint Hello World e o endpoint de exportação usando autenticação fornecida apenas no cliente HTTP; registrar somente status, cabeçalhos relevantes e corpo não sensível.
4. Localizar o JSON gerado, copiá-lo como `artifacts/local/hello-openapi.json` e validá-lo informando o parâmetro obrigatório `-Path`:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path artifacts/local/hello-openapi.json
   ```

5. Gerar o snapshot mínimo informando os parâmetros obrigatórios `-InputPath` e `-OutputPath`; depois, inspecionar e validar o arquivo resultante:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/extract-hello-openapi.ps1 -InputPath artifacts/local/hello-openapi.json -OutputPath examples/hello-world/snapshots/hello-openapi.json
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-hello-openapi.ps1 -Path examples/hello-world/snapshots/hello-openapi.json
   ```

6. Abrir a documentação nativa, localizar `GET /api/v1/hello` e registrar a versão, o path, a resposta documentada e eventuais limitações.
