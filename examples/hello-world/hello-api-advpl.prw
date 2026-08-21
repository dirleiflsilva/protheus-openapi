#include "totvs.ch"
#include "restful.ch"

/*/{Protheus.doc} HloAdv
Serviço REST mínimo para comparar a documentação AdvPL com TL++.
@type wsrestful
@author Dirlei Silva
@since 2026-08-21
/*/
WSRESTFUL HloAdv DESCRIPTION "Hello World AdvPL" FORMAT APPLICATION_JSON
    WSMETHOD GET Hello;
        DESCRIPTION "Retorna uma mensagem Hello World gerada por um endpoint AdvPL.";
        WSSYNTAX "/api/v1/hello-advpl";
        PATH "/api/v1/hello-advpl";
        PRODUCES APPLICATION_JSON
END WSRESTFUL

/*/{Protheus.doc} HloAdv::Hello
Retorna o contrato Hello World do experimento AdvPL.
@type method
@author Dirlei Silva
@since 2026-08-21
@return logical, Resultado do envio da resposta REST
/*/
WSMETHOD GET Hello WSSERVICE HloAdv

    Local lRet   := .T.
    Local jResp  := JsonObject():New()
    Local cResp  := ""

    jResp["message"]  := "Hello World"
    jResp["language"] := "AdvPL"
    jResp["status"]   := "success"
    cResp := jResp:ToJson()

    Self:SetContentType("application/json")
    Self:SetResponse(cResp)

Return lRet
