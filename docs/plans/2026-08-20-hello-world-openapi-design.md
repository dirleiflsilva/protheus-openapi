# Prova de conceito Hello World com OpenAPI no TL++

## Contexto

Antes do desenvolvimento da biblioteca Protheus OpenAPI, será criada uma prova de conceito mínima para observar o funcionamento nativo da documentação REST do TLPPCore. O experimento deve validar tanto a visualização da documentação quanto a geração do documento bruto em JSON.

O ambiente alvo possui as seguintes versões:

| Componente | Versão |
| --- | --- |
| Release Protheus | 12.1.2510 |
| AppServer | 24.3.1.5 |
| Build AppServer | 7.00.240223P, revisão SVN 46783 |
| LIB | 20251006 - 20250923_19220 |
| TLPPCore | 01.06.01 - TLPP PANTHERA ONCA |
| Revisão TLPPCore | dba1415fff954b22ba8cbd9cc9489421c7cecad2 |
| Build TLPPCore | 2026-01-09 20:24:45 |

O serviço existente utiliza o REST 2.0 do Protheus por meio de `[HTTPV11]`, com porta `8084`, URI base `/rest`, ambiente `P12_2510` e segurança habilitada. A URL base do experimento será `http://localhost:8084/rest`.

## Objetivos

- Publicar um endpoint `GET /api/v1/hello` em TL++ usando annotations.
- Confirmar sua execução pelo REST 2.0 existente.
- Observar como os metadados declarados no fonte aparecem na documentação nativa.
- Gerar uma especificação OpenAPI em JSON com `tlpp.doc.generate()`.
- Preservar o documento bruto localmente e versionar somente um fragmento revisado.
- Registrar diferenças entre o código, a operação gerada e o objetivo OpenAPI 3.0.3 da futura biblioteca.

## Fora do escopo

- Acesso a tabelas ou ao dicionário de dados do Protheus.
- Implementação da futura biblioteca OpenAPI.
- Alteração inicial do `appserver.ini`.
- Uso de parâmetros de path, query string ou body.
- Implementação de autenticação própria.
- Publicação de toda a documentação do ambiente no repositório.

## Abordagem escolhida

O primeiro teste utilizará o REST 2.0 já configurado. Nenhuma seção `[HTTPSERVER]` será adicionada inicialmente.

Caso os endpoints TL++ sejam executados, mas o gerador nativo não consiga descobrir ou documentar as rotas associadas ao `[HTTPV11]`, será configurado posteriormente um servidor TLPPCore independente, em outra porta. Essa configuração será um plano de contingência, não parte da primeira implementação.

## Estrutura proposta

```text
examples/
└── hello-world/
    ├── hello-api.tlpp
    └── openapi-export.tlpp

docs/
└── experiments/
    └── hello-world.md

artifacts/
└── local/              # ignorado pelo Git
```

Os fontes do experimento permanecerão isolados do núcleo futuro da biblioteca.

## Endpoint Hello World

O fonte `hello-api.tlpp` utilizará, nesta ordem:

```tlpp
#include "tlpp-core.th"
#include "tlpp-rest.th"
```

Uma `User Function` será associada a `GET /api/v1/hello` com os metadados `endpoint`, `title`, `description` e `responses`. O corpo será criado com `JsonObject`, sem concatenação manual de JSON.

Resposta esperada:

```json
{
  "message": "Hello World",
  "language": "TL++",
  "status": "success"
}
```

A operação responderá com HTTP `200` e `Content-Type: application/json`. Não haverá acesso a banco de dados, parâmetros, logs, interface ou variáveis de ambiente.

## Exportação OpenAPI

O fonte `openapi-export.tlpp` publicará um acionador experimental autenticado. Ele chamará a função nativa com escopo restrito à porta do serviço:

```tlpp
tlpp.doc.generate("json", "hello_openapi", {8084}, {"pt-br"})
```

O nome e o diretório efetivamente produzidos serão identificados durante a execução. O código não presumirá um caminho que não esteja garantido pela API.

O endpoint de exportação responderá apenas se a chamada terminou normalmente ou falhou. Ele não devolverá o conteúdo do arquivo, caminhos internos ou detalhes de exceção.

## Segurança e artefatos

A configuração existente `SECURITY=1` será preservada. Não serão adicionadas rotas públicas nem credenciais ao repositório.

Como o gerador pode coletar todas as rotas descobertas na porta `8084`, o documento bruto completo poderá conter endpoints do ambiente. Portanto:

- o JSON bruto será armazenado somente em `artifacts/local/`, ignorado pelo Git;
- somente o fragmento referente a `/api/v1/hello` será revisado e versionado;
- nenhum token, senha, cabeçalho de autenticação ou endpoint interno será publicado;
- o relatório do experimento registrará apenas informações necessárias para sua reprodução.

## Tratamento de falhas

- O endpoint Hello World retornará explicitamente o resultado esperado pelo framework REST.
- O acionador de exportação retornará HTTP `200` quando a solicitação terminar sem falha.
- Falhas de geração retornarão HTTP `500` com mensagem genérica.
- Detalhes técnicos serão observados no ambiente de desenvolvimento, sem exposição na resposta HTTP.
- A existência e a validade do arquivo serão verificadas separadamente após a chamada.

## Critérios de validação

1. `GET /rest/api/v1/hello` responde com HTTP `200`.
2. A resposta declara `Content-Type: application/json`.
3. O corpo contém exatamente `message`, `language` e `status` com os valores planejados.
4. `tlpp.doc.generate()` produz um arquivo JSON sintaticamente válido.
5. A versão OpenAPI ou Swagger declarada no documento é registrada sem pressuposição prévia.
6. `paths` contém uma operação `GET` correspondente ao Hello World.
7. Título, descrição e resposta `200` coincidem com os metadados do fonte.
8. O documento pode ser carregado em um visualizador compatível com sua versão declarada.
9. O relatório registra o caminho real do artefato e as limitações encontradas.

## Verificação de completude

- ✅ Execução do endpoint e geração do documento fazem parte do experimento.
- ✅ Visualização humana e captura do JSON bruto estão contempladas.
- ✅ Versões do ambiente serão preservadas no relatório.
- ✅ A segurança existente será mantida.
- ✅ O documento bruto completo não será publicado automaticamente.
- 🔄 O servidor `[HTTPSERVER]` independente permanece como contingência.
- ❓ O caminho do arquivo, a versão exata da especificação e a abrangência das rotas serão confirmados em runtime.

## Referências

- [REST server TLPPCore](https://tdn.totvs.com/display/tec/Rest)
- [REST 2.0 no Protheus](https://tdn.totvs.com/display/framework/Entendendo%2Bas%2Bnovidades%2Bdo%2BREST)
- [Metadados da annotation REST](https://totvs.github.io/totvstec-doc/docs/tlpp/rest/metadados/rest-annotation)
- [Geração OpenAPI com `tlpp.doc.generate()`](https://totvs.github.io/totvstec-doc/docs/tlpp/rest/doc-generate)
- [Exemplos oficiais do motor REST-DOC](https://github.com/totvs/tlpp-sample-rest-documentation)
