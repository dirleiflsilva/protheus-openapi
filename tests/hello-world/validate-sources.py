#!/usr/bin/env python
"""Valida o contrato estatico dos fontes hello-world (hello/export/advpl).

Porte de tests/hello-world/validate-sources.ps1.
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class ContractError(Exception):
    pass


def _contracts():
    return {
        "hello": {
            "path": REPO_ROOT / "examples" / "hello-world" / "hello-api.tlpp",
            "documentation_patterns": [
                r"(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$",
                r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
                r"(?m)^[\t ]*@since[\t ]+2026-08-20[\t ]*\r?$",
                r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$",
            ],
            "declaration_pattern": (
                r"(?ms)/\*/\{Protheus\.doc\}(?P<body>.*?)\*/[\t \r\n]*"
                r"^[\t ]*@Get[\t ]*\([\t ]*;[^\r\n]*\r?$.*?^[\t ]*\)[\t ]*\r?$[\t \r\n]*"
                r"^[\t ]*User[\t ]+Function[\t ]+HloApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$"
            ),
            "patterns": [
                r'(?m)^[\t ]*#include[\t ]+"tlpp-core\.th"[\t ]*\r?$',
                r'(?m)^[\t ]*#include[\t ]+"tlpp-rest\.th"[\t ]*\r?$',
                r"(?m)^[\t ]*@Get[\t ]*\([\t ]*;[\t ]*\r?$",
                r'(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*\bendpoint[\t ]*=[\t ]*"/api/v1/hello"[^\r\n]*\r?$',
                r'(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*\btitle[\t ]*=[\t ]*"Hello World"[^\r\n]*\r?$',
                r'(?m)^[\t ]*description[\t ]*=[\t ]*"Retorna uma mensagem Hello World gerada por um endpoint TL\+\+\."[\t ]*,?[\t ]*;?[\t ]*\r?$',
                r"(?m)^[\t ]*User[\t ]+Function[\t ]+HloApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$",
                r"(?m)^[\t ]*(?!//|/\*|\*)[^\r\n]*JsonObject[\t ]*\(\)[\t ]*:[\t ]*New[\t ]*\(\)",
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Hello World"[\t ]*\r?$',
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"language"[\t ]*\][\t ]*:=[\t ]*"TL\+\+"[\t ]*\r?$',
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"success"[\t ]*\r?$',
                r"(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$",
                r"(?m)^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)[\t ]*\r?$",
                r'(?m)^[\t ]*oRest[\t ]*:[\t ]*SetKeyHeaderResponse[\t ]*\([\t ]*"Content-Type"[\t ]*,[\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
                r"(?m)^[\t ]*Return[\t ]+oRest[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$",
            ],
            "responses": [{"statusCode": 200, "description": "Hello World retornado com sucesso."}],
        },
        "export": {
            "path": REPO_ROOT / "examples" / "hello-world" / "openapi-export.tlpp",
            "documentation_patterns": [
                r"(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$",
                r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
                r"(?m)^[\t ]*@since[\t ]+2026-08-20[\t ]*\r?$",
                r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$",
            ],
            "declaration_pattern": (
                r"(?ms)/\*/\{Protheus\.doc\}(?P<body>.*?)\*/[\t \r\n]*"
                r"^[\t ]*@Get[\t ]*\([\t ]*;[^\r\n]*\r?$.*?^[\t ]*\)[\t ]*\r?$[\t \r\n]*"
                r"^[\t ]*User[\t ]+Function[\t ]+GenOApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$"
            ),
            "patterns": [
                r'(?m)^[\t ]*#include[\t ]+"tlpp-core\.th"[\t ]*\r?$',
                r'(?m)^[\t ]*#include[\t ]+"tlpp-rest\.th"[\t ]*\r?$',
                r"(?m)^[\t ]*@Get[\t ]*\([\t ]*;[\t ]*\r?$",
                r'(?m)^[\t ]*endpoint[\t ]*=[\t ]*"/api/v1/openapi/export"[\t ]*,?[\t ]*;?[\t ]*\r?$',
                r'(?m)^[\t ]*title[\t ]*=[\t ]*"Exportar OpenAPI"[\t ]*,?[\t ]*;?[\t ]*\r?$',
                r'(?m)^[\t ]*description[\t ]*=[\t ]*"Gera o documento OpenAPI das rotas descobertas na porta REST 8084\."[\t ]*,?[\t ]*;?[\t ]*\r?$',
                r"(?m)^[\t ]*User[\t ]+Function[\t ]+GenOApi[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$",
                r"(?m)^[\t ]*Local[\t ]+lOk[\t ]*:=[\t ]*\.T\.[\t ]+as[\t ]+Logical[\t ]*\r?$",
                r"(?m)^[\t ]*Local[\t ]+jResp[\t ]*:=[\t ]*JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([\t ]*\)[\t ]+as[\t ]+Json[\t ]*\r?$",
                (
                    r"(?ms)^[\t ]*Begin[\t ]+Sequence[\t ]*\r?$[\t \r\n]*"
                    r'^[\t ]*tlpp\.doc\.generate[\t ]*\([\t ]*"swagger"[\t ]*,[\t ]*"hello_openapi"[\t ]*,[\t ]*\{[\t ]*8084[\t ]*\}[\t ]*,[\t ]*\{[\t ]*"pt-br"[\t ]*\}[\t ]*\)[\t ]*\r?$[\t \r\n]*'
                    r"^[\t ]*Recover[\t ]*\r?$[\t \r\n]*"
                    r"^[\t ]*lOk[\t ]*:=[\t ]*\.F\.[\t ]*\r?$[\t \r\n]*"
                    r"^[\t ]*End[\t ]+Sequence[\t ]*\r?$"
                ),
                (
                    r"(?ms)^[\t ]*If[\t ]+lOk[\t ]*\r?$[\t \r\n]*"
                    r'^[\t ]*jResp[\t ]*\[[\t ]*"success"[\t ]*\][\t ]*:=[\t ]*\.T\.[\t ]*\r?$[\t \r\n]*'
                    r'^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Exportação OpenAPI solicitada com sucesso\."[\t ]*\r?$[\t \r\n]*'
                    r"^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)[\t ]*\r?$[\t \r\n]*"
                    r"^[\t ]*Else[\t ]*\r?$[\t \r\n]*"
                    r'^[\t ]*jResp[\t ]*\[[\t ]*"success"[\t ]*\][\t ]*:=[\t ]*\.F\.[\t ]*\r?$[\t \r\n]*'
                    r'^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Falha ao solicitar a exportação OpenAPI\."[\t ]*\r?$[\t \r\n]*'
                    r"^[\t ]*oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*500[\t ]*\)[\t ]*\r?$[\t \r\n]*"
                    r"^[\t ]*EndIf[\t ]*\r?$"
                ),
                r"(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$",
                r'(?m)^[\t ]*oRest[\t ]*:[\t ]*SetKeyHeaderResponse[\t ]*\([\t ]*"Content-Type"[\t ]*,[\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
                r"(?m)^[\t ]*Return[\t ]+oRest[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$",
            ],
            "responses": [
                {"statusCode": 200, "description": "Exportação solicitada com sucesso."},
                {"statusCode": 500, "description": "Falha ao solicitar a exportação."},
            ],
        },
        "advpl": {
            "path": REPO_ROOT / "examples" / "hello-world" / "hello-api-advpl.prw",
            "documentation_patterns": [
                r"(?m)^/\*/\{Protheus\.doc\} api[\t ]*\r?$",
                r"(?m)^[\t ]*@type[\t ]+wsrestful[\t ]*\r?$",
                r"(?m)^/\*/\{Protheus\.doc\} api::Hello[\t ]*\r?$",
                r"(?m)^[\t ]*@type[\t ]+method[\t ]*\r?$",
                r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
                r"(?m)^[\t ]*@since[\t ]+2026-08-21[\t ]*\r?$",
                r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+Resultado do envio da resposta REST[\t ]*\r?$",
            ],
            "declaration_pattern": (
                r"(?ms)(?P<body>/\*/\{Protheus\.doc\} api.*?)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]+WSSERVICE[\t ]+api[\t ]*\r?$"
            ),
            "patterns": [
                r'(?m)^[\t ]*#include[\t ]+"totvs\.ch"[\t ]*\r?$',
                r'(?m)^[\t ]*#include[\t ]+"restful\.ch"[\t ]*\r?$',
                r'(?m)^[\t ]*WSRESTFUL[\t ]+api[\t ]+DESCRIPTION[\t ]+"Hello World AdvPL"[\t ]+FORMAT[\t ]+APPLICATION_JSON[\t ]*\r?$',
                r"(?m)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]*;[\t ]*\r?$",
                r'(?m)^[\t ]*DESCRIPTION[\t ]+"Retorna uma mensagem Hello World gerada por um endpoint AdvPL\."[\t ]*;[\t ]*\r?$',
                r'(?m)^[\t ]*WSSYNTAX[\t ]+"/v1/hello-advpl"[\t ]*;[\t ]*\r?$',
                r'(?m)^[\t ]*PATH[\t ]+"/v1/hello-advpl"[\t ]*;[\t ]*\r?$',
                r"(?m)^[\t ]*PRODUCES[\t ]+APPLICATION_JSON[\t ]*\r?$",
                r"(?m)^[\t ]*END[\t ]+WSRESTFUL[\t ]*\r?$",
                r"(?m)^[\t ]*WSMETHOD[\t ]+GET[\t ]+Hello[\t ]+WSSERVICE[\t ]+api[\t ]*\r?$",
                r"(?m)^[\t ]*Local[\t ]+lRet[\t ]*:=[\t ]*\.T\.[\t ]*\r?$",
                r"(?m)^[\t ]*Local[\t ]+jResp[\t ]*:=[\t ]*JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([\t ]*\)[\t ]*\r?$",
                r'(?m)^[\t ]*Local[\t ]+cResp[\t ]*:=[\t ]*""[\t ]*\r?$',
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Hello World"[\t ]*\r?$',
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"language"[\t ]*\][\t ]*:=[\t ]*"AdvPL"[\t ]*\r?$',
                r'(?m)^[\t ]*jResp[\t ]*\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"success"[\t ]*\r?$',
                r"(?m)^[\t ]*cResp[\t ]*:=[\t ]*jResp[\t ]*:[\t ]*ToJson[\t ]*\([\t ]*\)[\t ]*\r?$",
                r'(?m)^[\t ]*Self[\t ]*:[\t ]*SetContentType[\t ]*\([\t ]*"application/json"[\t ]*\)[\t ]*\r?$',
                r"(?m)^[\t ]*Self[\t ]*:[\t ]*SetResponse[\t ]*\([\t ]*cResp[\t ]*\)[\t ]*\r?$",
                r"(?m)^[\t ]*Return[\t ]+lRet[\t ]*\r?$",
            ],
            "responses": [],
        },
    }


def _read_contract_source(path: Path) -> str:
    data = path.read_bytes()

    has_utf8_bom = data[:3] == b"\xef\xbb\xbf"
    has_utf16_le_bom = len(data) >= 2 and data[0] == 0xFF and data[1] == 0xFE
    has_utf16_be_bom = len(data) >= 2 and data[0] == 0xFE and data[1] == 0xFF
    has_utf32_le_bom = len(data) >= 4 and data[0:4] == bytes([0xFF, 0xFE, 0x00, 0x00])
    has_utf32_be_bom = len(data) >= 4 and data[0:4] == bytes([0x00, 0x00, 0xFE, 0xFF])

    if has_utf8_bom or has_utf16_le_bom or has_utf16_be_bom or has_utf32_le_bom or has_utf32_be_bom:
        raise ContractError(f"O fonte possui BOM não permitido: {path}")

    has_non_ascii = any(byte > 0x7F for byte in data)
    if has_non_ascii:
        # CP1252 e UTF-8 sem BOM podem produzir sequências de bytes ambíguas.
        # Esta heurística complementa, mas não substitui, a conversão controlada
        # pelo script oficial de encoding usado na geração dos fontes Protheus.
        try:
            data.decode("utf-8", errors="strict")
            raise ContractError(f"O fonte está em UTF-8 sem BOM: {path}")
        except UnicodeDecodeError:
            pass

    return data.decode("cp1252")


def validate_target(name, contract):
    path = contract["path"]
    if not path.is_file():
        raise ContractError(f"Fonte não encontrado: {path}")

    content = _read_contract_source(path)

    if contract["documentation_patterns"]:
        match = re.search(contract["declaration_pattern"], content)
        if not match:
            raise ContractError(f"Sequência ProtheusDOC, annotation e função ausente em {name}.")
        body = match.group("body")
        for pattern in contract["documentation_patterns"]:
            if not re.search(pattern, body):
                raise ContractError(f"Contrato ProtheusDOC ausente em {name}: {pattern}")

    # Remoção simples para esta POC. Não substitui um parser TL++ e pressupõe
    # que os valores contratuais não contenham marcadores de comentário em strings.
    validation_content = re.sub(r"(?s)/\*.*?\*/", "", content)
    validation_content = re.sub(r"(?m)//[^\r\n]*", "", validation_content)

    for pattern in contract["patterns"]:
        if not re.search(pattern, validation_content):
            raise ContractError(f"Contrato ausente em {name}: {pattern}")

    expected_responses = contract["responses"]
    if expected_responses:
        matches = list(
            re.finditer(
                r"(?m)^[\t ]*responses[\t ]*=[\t ]*'(?P<json>[^'\r\n]*)'[\t ]*;?[\t ]*,?[\t ]*\r?$",
                validation_content,
            )
        )
        if len(matches) != 1:
            raise ContractError(f"Propriedade responses ausente ou duplicada em {name}.")

        responses_json = matches[0].group("json").strip()
        if not (responses_json.startswith("[") and responses_json.endswith("]")):
            raise ContractError(f"responses deve ser um array JSON em {name}.")

        try:
            parsed = json.loads(responses_json)
        except json.JSONDecodeError as exc:
            raise ContractError(f"JSON inválido em responses de {name}: {exc}") from exc

        if not isinstance(parsed, list):
            raise ContractError(f"responses deve ser um array JSON em {name}.")

        if len(parsed) != len(expected_responses):
            raise ContractError(
                f"Quantidade de responses inválida em {name}: esperado {len(expected_responses)}, "
                f"obtido {len(parsed)}."
            )

        for index, (expected, actual) in enumerate(zip(expected_responses, parsed)):
            if not isinstance(actual, dict):
                raise ContractError(f"Response inválido em {name} na posição {index}: esperado um objeto JSON.")

            keys = set(actual.keys())
            if "statusCode" not in keys or "description" not in keys:
                raise ContractError(
                    f"Response inválido em {name} na posição {index}: propriedades obrigatórias ausentes."
                )
            if len(keys) != 2:
                raise ContractError(
                    f"Response inválido em {name} na posição {index}: propriedades extras não são permitidas."
                )

            status_code = actual.get("statusCode")
            is_int = isinstance(status_code, int) and not isinstance(status_code, bool)
            if (
                not is_int
                or status_code != expected["statusCode"]
                or actual.get("description") != expected["description"]
            ):
                raise ContractError(
                    f"Response inválido em {name} na posição {index}: esperado "
                    f"statusCode={expected['statusCode']} e description='{expected['description']}'."
                )

    return f"Contrato {name} válido."


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, choices=["hello", "export", "advpl"])
    args = parser.parse_args(argv)

    contracts = _contracts()
    try:
        message = validate_target(args.target, contracts[args.target])
    except ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(message)
    return 0


if __name__ == "__main__":
    sys.exit(main())
