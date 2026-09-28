#include "totvs.ch"
#include "restful.ch"

/*/{Protheus.doc} HelloAdvpl
Servico REST de exemplo para a Fase 4 do Protheus OpenAPI. Demonstra um servico
WSRESTFUL com WSDATA, dois metodos (GET e POST) e PATH absoluto, exercitando o
adaptador AdvPL que faz parsing do bloco de definicao.
@type wsrestful
@author Dirlei Silva
@since 2026-09-26
/*/
WSRESTFUL HelloAdvpl DESCRIPTION "Hello World AdvPL com parametros" FORMAT "application/json"
    WSDATA language AS STRING OPTIONAL
    WSMETHOD GET Hello;
        DESCRIPTION "Retorna uma mensagem Hello World gerada por um endpoint AdvPL.";
        WSSYNTAX "/api/v1/hello-advpl?{language}";
        PATH "/api/v1/hello-advpl";
        PRODUCES APPLICATION_JSON
    WSMETHOD POST Hello;
        DESCRIPTION "Cria uma mensagem Hello World em AdvPL.";
        WSSYNTAX "/api/v1/hello-advpl";
        PATH "/api/v1/hello-advpl";
        PRODUCES APPLICATION_JSON
END WSRESTFUL

/*/{Protheus.doc} HelloAdvpl::Hello (GET)
Retorna o contrato Hello World do adaptador AdvPL.
@type method
@author Dirlei Silva
@since 2026-09-26
@return logical, Resultado do envio da resposta REST
/*/
WSMETHOD GET Hello WSRECEIVE language WSSERVICE HelloAdvpl

    Local lRet  := .T.
    Local jResp := JsonObject():New()
    Local cResp := ""

    Default Self:language := "AdvPL"

    jResp["message"]  := "Hello World"
    jResp["language"] := Self:language
    jResp["status"]   := "success"
    cResp := jResp:ToJson()

    Self:SetContentType("application/json")
    Self:SetResponse(cResp)

Return lRet

/*/{Protheus.doc} HelloAdvpl::Hello (POST)
Cria uma mensagem Hello World via POST.
@type method
@author Dirlei Silva
@since 2026-09-26
@return logical, Resultado do envio da resposta REST
/*/
WSMETHOD POST Hello WSSERVICE HelloAdvpl

    Local lRet  := .T.
    Local jResp := JsonObject():New()
    Local cResp := ""

    jResp["message"]  := "Hello World"
    jResp["language"] := "AdvPL"
    jResp["status"]   := "created"
    cResp := jResp:ToJson()

    Self:SetContentType("application/json")
    Self:SetResponse(cResp)

Return lRet
