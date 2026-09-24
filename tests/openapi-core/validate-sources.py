#!/usr/bin/env python
"""Valida o contrato estatico do nucleo OpenAPI (todas as classes e endpoints).

Porte de tests/openapi-core/validate-sources.ps1. O arquivo original e
extremamente repetitivo (a mesma sequencia de checagens - includes,
namespace, ProtheusDoc por metodo, declaracao/implementacao por metodo -
copiada a mao para cada uma das 9 classes do nucleo); aqui essa sequencia
vira uma funcao unica (`check_class`) dirigida por uma tabela de
especificacoes por classe, preservando as mesmas mensagens de erro e a
mesma ordem de verificacao.
"""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class ContractError(Exception):
    pass


def get_cp1252_content(path: Path, not_found_message=None):
    if not path.is_file():
        raise ContractError(not_found_message or f"Fonte de teste não encontrado: {path}")

    data = path.read_bytes()
    has_bom = (data[:3] == b"\xef\xbb\xbf") or (
        len(data) >= 2 and ((data[0] == 0xFF and data[1] == 0xFE) or (data[0] == 0xFE and data[1] == 0xFF))
    )
    if has_bom:
        raise ContractError(f"O fonte possui BOM não permitido: {path}")

    has_non_ascii = any(byte > 0x7F for byte in data)
    if has_non_ascii:
        try:
            data.decode("utf-8", errors="strict")
            raise ContractError(f"O fonte está em UTF-8 sem BOM: {path}")
        except UnicodeDecodeError:
            pass

    return data.decode("cp1252")


def assert_match(content, pattern, message):
    if not re.search(pattern, content):
        raise ContractError(message)


def strip_comments(content):
    without_block = re.sub(r"(?s)/\*.*?\*/", "", content)
    return re.sub(r"(?m)//[^\r\n]*", "", without_block)


_INCLUDE_RE = re.compile(r'(?im)^[\t ]*#include[\t ]+["\'](?P<name>[^"\']+)["\'][\t ]*\r?$')


def check_includes(content, expected, display_name):
    includes = [m.group("name") for m in _INCLUDE_RE.finditer(content)]
    if len(includes) < len(expected):
        raise ContractError(f"Includes obrigatórios ausentes no fonte {display_name}.")
    for index, name in enumerate(expected):
        if includes[index] != name:
            raise ContractError(
                f"Ordem de includes inválida no {display_name}: esperado '{name}' na posição {index + 1}."
            )


# --- Checagem generica de classe do nucleo ---------------------------------

def check_class(spec):
    """spec: dict com file_path, class_name, namespace, includes, class_since, methods.

    methods: lista de dicts {name, since, patterns} onde `patterns` sao os
    requisitos especificos do metodo (@param/@return); o trio comum
    (@type method, @author, @since) e verificado automaticamente.
    """
    class_name = spec["class_name"]
    path = spec["file_path"]

    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, spec["includes"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+" + re.escape(spec["namespace"]) + r"[\t ]*\r?$",
        f"Namespace {spec['namespace']} ausente no {class_name}.",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    method_docs = {}
    for method in spec["methods"]:
        name = method["name"]
        doc_match = re.search(
            rf"(?is)(?P<doc>/\*/\{{Protheus\.doc\}}[\t ]+{class_name}::{name}\b.*?\*/)[\t \r\n]*method[\t ]+{name}[\t ]*\(",
            content,
        )
        if not doc_match:
            raise ContractError(f"ProtheusDOC obrigatório ausente para {class_name}::{name}.")
        doc_body = doc_match.group("doc")
        method_docs[name] = doc_body

        trio = [
            r"(?im)^[\t ]*@type[\t ]+method\b",
            r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
            rf"(?im)^[\t ]*@since[\t ]+{method['since']}\b",
        ]
        for pattern in trio + method.get("patterns", []):
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+{spec['class_since']}\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
        ),
        f"ProtheusDOC obrigatório ausente para a classe {class_name}.",
    )

    validation_content = strip_comments(content)

    for method in spec["methods"]:
        name = method["name"]
        assert_match(
            validation_content,
            rf"(?im)^[\t ]*public[\t ]+method[\t ]+{name}[\t ]*\(",
            f"Método público {class_name}::{name} ausente na declaração da classe.",
        )
        assert_match(
            validation_content,
            rf"(?im)^[\t ]*method[\t ]+{name}[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+{class_name}\b",
            f"Implementação {class_name}::{name} ausente.",
        )

    for fn in spec.get("static_functions", []):
        assert_match(
            validation_content,
            rf"(?im)^[\t ]*Static[\t ]+Function[\t ]+{fn}[\t ]*\(",
            f"Função auxiliar privada {fn} ausente no {class_name}.",
        )

    return content, validation_content, method_docs


def _m(name, since, patterns=None):
    return {"name": name, "since": since, "patterns": patterns or []}


def _core_class_specs():
    core = REPO_ROOT / "src" / "core"
    includes_default = ["tlpp-core.th", "totvs.ch"]
    namespace = "custom.openapi.core"

    return [
        {
            "file_path": core / "custom.openapi.info.tlpp",
            "class_name": "OApiInfo",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-24",
            "methods": [
                _m(
                    "new",
                    "2026-08-24",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cTitle,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cApiVer,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getTitle", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getDesc", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getVer", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("validate", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
        {
            "file_path": core / "custom.openapi.response.tlpp",
            "class_name": "OApiResp",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-24",
            "methods": [
                _m(
                    "new",
                    "2026-08-24",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cCode,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getCode", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getDesc", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("validate", "2026-08-24", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "setSchema",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getSchema", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
        {
            "file_path": core / "custom.openapi.operation.tlpp",
            "class_name": "OApiOper",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-25",
            "methods": [
                _m(
                    "new",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cMethod,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cSummary,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getMethod", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getSummary", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getDesc", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getResps", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addResp",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oResp,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("validate", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m("getParams", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addParam",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oParam,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getBody", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "setBody",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oBody,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
            ],
        },
        {
            "file_path": core / "custom.openapi.path.tlpp",
            "class_name": "OApiPath",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-25",
            "methods": [
                _m(
                    "new",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cPath,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getPath", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getOpers", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addOper",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oOper,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("validate", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
        {
            "file_path": core / "custom.openapi.document.tlpp",
            "class_name": "OApiDoc",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-25",
            "static_functions": ["DocNameOk", "RefPend"],
            "methods": [
                _m(
                    "new",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oInfo,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getOpenApi", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getInfo", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
                _m("getPaths", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addPath",
                    "2026-08-25",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oPath,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("validate", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m("getSchemas", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addSchema",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cName,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
            ],
        },
        {
            "file_path": core / "custom.openapi.schema.tlpp",
            "class_name": "OApiSchema",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-26",
            "static_functions": ["SchNameOk"],
            "methods": [
                _m(
                    "new",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cKind,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getKind", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "addProp",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cName,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+lReq,[\t ]+logical,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getProps", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "setItems",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getItems", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
                _m(
                    "setRef",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cName,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getRef", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("validate", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
        {
            "file_path": core / "custom.openapi.parameter.tlpp",
            "class_name": "OApiParam",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-26",
            "methods": [
                _m(
                    "new",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+cName,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cIn,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+lReq,[\t ]+logical,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getName", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getIn", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("getReq", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$"]),
                _m("getSchema", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
                _m("getDesc", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("validate", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
        {
            "file_path": core / "custom.openapi.body.tlpp",
            "class_name": "OApiBody",
            "namespace": namespace,
            "includes": includes_default,
            "class_since": "2026-08-26",
            "methods": [
                _m(
                    "new",
                    "2026-08-26",
                    [
                        r"(?im)^[\t ]*@param[\t ]+lReq,[\t ]+logical,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+oSchema,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@param[\t ]+cDesc,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                        r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    ],
                ),
                _m("getReq", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$"]),
                _m("getSchema", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
                _m("getDesc", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$"]),
                _m("validate", "2026-08-26", [r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$"]),
            ],
        },
    ]


# --- OApiJson: checagens estruturais adicionais alem do padrao de classe ---

def check_json_class():
    core = REPO_ROOT / "src" / "core"
    spec = {
        "file_path": core / "custom.openapi.json.tlpp",
        "class_name": "OApiJson",
        "namespace": "custom.openapi.core",
        "includes": ["tlpp-core.th", "totvs.ch"],
        "class_since": "2026-08-25",
        "static_functions": ["SchToJson"],
        "methods": [
            _m("new", "2026-08-25", [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]),
            _m(
                "toJson",
                "2026-08-25",
                [
                    r"(?im)^[\t ]*@param[\t ]+oDoc,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                    r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$",
                ],
            ),
        ],
    }
    _content, validation_content, _docs = check_class(spec)

    to_json_match = re.search(
        r"(?is)method[\t ]+toJson[\t ]*\([^\r\n]*\)[^\r\n]*class[\t ]+OApiJson\b(?P<body>.*?)(?=^[\t ]*method\b|\Z)",
        validation_content,
        re.MULTILINE,
    )
    if not to_json_match:
        raise ContractError("Corpo de OApiJson::toJson não encontrado.")

    to_json_body = to_json_match.group("body")
    validate_match = re.search(r"(?i)oDoc[\t ]*:[\t ]*validate[\t ]*\(", to_json_body)
    new_match = re.search(r"(?i)JsonObject[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(", to_json_body)
    serialize_match = re.search(r"(?i):[\t ]*ToJson[\t ]*\(", to_json_body)

    if not validate_match:
        raise ContractError("OApiJson::toJson deve validar o documento antes de serializar.")
    if not new_match:
        raise ContractError("JsonObject():New() ausente em OApiJson::toJson.")
    if validate_match.start() > new_match.start():
        raise ContractError("OApiJson::toJson deve validar antes de criar a saída JSON.")
    if not serialize_match or serialize_match.start() < new_match.start():
        raise ContractError("ToJson() ausente após a criação do objeto JSON.")

    for pattern in [
        r'(?i)\[[\t ]*"parameters"[\t ]*\]',
        r'(?i)\[[\t ]*"requestBody"[\t ]*\]',
        r'(?i)\[[\t ]*"content"[\t ]*\]',
        r'(?i)\[[\t ]*"application/json"[\t ]*\]',
        r'(?i)\[[\t ]*"components"[\t ]*\]',
        r'(?i)\[[\t ]*"\$ref"[\t ]*\]',
        r'(?i)\[[\t ]*"required"[\t ]*\]',
        r'(?i)\[[\t ]*"items"[\t ]*\]',
        r'(?i)\[[\t ]*"properties"[\t ]*\]',
    ]:
        assert_match(validation_content, pattern, f"Serialização obrigatória ausente no OApiJson: {pattern}")


# --- Fixture PROBAT (tests/openapi-core/custom.openapi.core.test.tlpp) -----

def check_test_fixture():
    path = REPO_ROOT / "tests" / "openapi-core" / "custom.openapi.core.test.tlpp"
    content = get_cp1252_content(path, f"Fonte de teste não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "tlpp-probat.th", "totvs.ch"], "PROBAT")

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.core\.test[\t ]*\r?$",
        "Namespace custom.openapi.core.test ausente.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+tlpp\.probat[\t ]*\r?$",
        "Importação do namespace tlpp.probat ausente.",
    )

    fixture_match = re.search(
        (
            r"(?ms)(?P<doc>/\*/\{Protheus\.doc\}.*?\*/)[\t \r\n]*@TestFixture[\t ]*\([\t ]*\)[\t \r\n]*"
            r"User[\t ]+Function[\t ]+OApiTst[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$"
        ),
        content,
    )
    if not fixture_match:
        raise ContractError("Sequência ProtheusDOC, @TestFixture() e User Function OApiTst() ausente.")

    doc_body = fixture_match.group("doc")
    for pattern in [
        r"(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$",
        r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
        r"(?m)^[\t ]*@since[\t ]+2026-08-24[\t ]*\r?$",
        r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$",
    ]:
        assert_match(doc_body, pattern, f"ProtheusDOC obrigatório ausente no fixture: {pattern}")

    validation_content = strip_comments(content)
    assert_match(
        validation_content,
        r"(?im)^[\t ]*assertEquals[\t ]*\([\t ]*\.T\.[\t ]*,[\t ]*\.T\.",
        "Asserção smoke GREEN do PROBAT ausente.",
    )


# --- Endpoint de demonstracao (examples/openapi-core/custom.openapi.core.api.tlpp)

def check_api_endpoint():
    path = REPO_ROOT / "examples" / "openapi-core" / "custom.openapi.core.api.tlpp"
    content = get_cp1252_content(path, f"Fonte do endpoint OApiCore não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "tlpp-rest.th", "totvs.ch"], "OApiCore")

    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.core[\t ]*\r?$",
        "Importação do namespace custom.openapi.core ausente no OApiCore.",
    )

    decl_match = re.search(
        (
            r"(?ims)(?P<doc>/\*/\{Protheus\.doc\}.*?\*/)[\t \r\n]*(?P<annotation>@Get[\t ]*\([\s\S]*?^[\t ]*\))"
            r"[\t \r\n]*User[\t ]+Function[\t ]+OApiCore[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical\b"
        ),
        content,
    )
    if not decl_match:
        raise ContractError("Sequência ProtheusDOC, @Get e User Function OApiCore() as Logical ausente.")

    for pattern in [
        r"(?im)^[\t ]*@type[\t ]+function\b",
        r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
        r"(?im)^[\t ]*@since[\t ]+2026-08-25\b",
        r"(?im)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$",
    ]:
        assert_match(decl_match.group("doc"), pattern, f"ProtheusDOC incompleto no endpoint OApiCore: {pattern}")

    annotation = decl_match.group("annotation")
    for pattern in [
        r'(?i)\bendpoint[\t ]*=[\t ]*"/api/v1/openapi/core"',
        r'(?i)\btitle[\t ]*=[\t ]*"[^"\r\n]+"',
        r'(?i)\bdescription[\t ]*=[\t ]*"[^"\r\n]+"',
        r'(?i)"statusCode"[\t ]*:[\t ]*200',
        r'(?i)"statusCode"[\t ]*:[\t ]*500',
    ]:
        assert_match(annotation, pattern, f"Metadado @Get obrigatório ausente no OApiCore: {pattern}")

    validation_content = strip_comments(content)

    for class_name in [
        "OApiInfo",
        "OApiResp",
        "OApiOper",
        "OApiPath",
        "OApiDoc",
        "OApiJson",
        "OApiSchema",
        "OApiParam",
        "OApiBody",
    ]:
        assert_match(
            validation_content,
            rf"(?i)\b{class_name}[\t ]*\([\t ]*\)[\t ]*:[\t ]*new[\t ]*\(",
            f"Uso da classe {class_name} ausente no endpoint OApiCore.",
        )

    for pattern in [
        r"(?i):[\t ]*addSchema[\t ]*\(",
        r"(?i):[\t ]*addParam[\t ]*\(",
        r"(?i):[\t ]*setBody[\t ]*\(",
        r"(?i):[\t ]*setSchema[\t ]*\(",
        r'(?i):[\t ]*setRef[\t ]*\([\t ]*"HelloRequest"',
        r'(?i):[\t ]*setRef[\t ]*\([\t ]*"HelloResponse"',
        r'(?i):[\t ]*setRef[\t ]*\([\t ]*"ErrorResponse"',
    ]:
        assert_match(validation_content, pattern, f"Enriquecimento obrigatório ausente no endpoint OApiCore: {pattern}")

    for pattern in [
        r'(?i)OApiResp[\t ]*\([\t ]*\)[\t ]*:[\t ]*new[\t ]*\([\t ]*"200"',
        r'(?i)OApiOper[\t ]*\([\t ]*\)[\t ]*:[\t ]*new[\t ]*\([\s\S]*?"GET"',
        r'(?i)OApiPath[\t ]*\([\t ]*\)[\t ]*:[\t ]*new[\t ]*\([\t ]*"/api/v1/hello"',
        r"(?i):[\t ]*toJson[\t ]*\(",
        r"(?im)^[\t ]*Try[\t ]*\r?$",
        r"(?im)^[\t ]*Catch[\t ]+oError[\t ]*\r?$",
        r"(?im)^[\t ]*EndTry[\t ]*\r?$",
        r"(?i)oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)",
        r"(?i)oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*500[\t ]*\)",
        r'(?i)oRest[\t ]*:[\t ]*SetKeyHeaderResponse[\t ]*\([\t ]*"Content-Type"[\t ]*,[\t ]*"application/json"[\t ]*\)',
        r"(?i)oRest[\t ]*:[\t ]*SetResponse[\t ]*\(",
        r'(?i)\[[\t ]*"success"[\t ]*\][\t ]*:=[\t ]*\.F\.',
        r'(?i)\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Falha ao gerar o documento OpenAPI\."',
    ]:
        assert_match(validation_content, pattern, f"Contrato REST obrigatório ausente no OApiCore: {pattern}")

    forbidden = {
        r"(?i)oError[\t ]*:[\t ]*(Description|ErrorStack|Stack)": "Detalhes internos do erro não podem ser enviados ao cliente.",
        r"(?i)\b(RpcSetEnv|RpcSetType|ConOut|IIF)[\t ]*\(": "API proibida no endpoint OApiCore.",
        r"(?i)\b(password|passwd|client_?secret|api_?key)[\t ]*:?=": "Credencial não pode ser declarada no endpoint OApiCore.",
        r"(?i)\bAuthorization\b": "Credencial ou cabeçalho Authorization não deve ser hardcoded no endpoint OApiCore.",
    }
    for pattern, message in forbidden.items():
        if re.search(pattern, validation_content):
            raise ContractError(f"{message} Fonte: {path}")


def check_hello_endpoints():
    get_path = REPO_ROOT / "examples" / "openapi-parameters-schemas" / "custom.openapi.hello.get.tlpp"
    post_path = REPO_ROOT / "examples" / "openapi-parameters-schemas" / "custom.openapi.hello.post.tlpp"

    get_content = get_cp1252_content(get_path, f"Fonte do endpoint HeloGet não encontrado: {get_path}")
    get_validation = strip_comments(get_content)

    for pattern in [
        r'(?i)\bendpoint[\t ]*=[\t ]*"/api/v1/hello/:name"',
        r"(?im)^[\t ]*User[\t ]+Function[\t ]+HeloGet[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical\b",
        r"(?i)oRest[\t ]*:[\t ]*GetPathParamsRequest[\t ]*\(",
        r"(?i)oRest[\t ]*:[\t ]*GetQueryRequest[\t ]*\(",
        r'(?i)\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Hello[\t ]*"[\t ]*\+',
        r'(?i)\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"success"',
        r"(?i)oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)",
        r"(?i)oRest[\t ]*:[\t ]*SetResponse[\t ]*\(",
    ]:
        assert_match(get_validation, pattern, f"Contrato obrigatório ausente no endpoint HeloGet: {pattern}")

    post_content = get_cp1252_content(post_path, f"Fonte do endpoint HeloPost não encontrado: {post_path}")
    post_validation = strip_comments(post_content)

    for pattern in [
        r'(?i)\bendpoint[\t ]*=[\t ]*"/api/v1/hello"',
        r"(?im)^[\t ]*User[\t ]+Function[\t ]+HeloPost[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical\b",
        r"(?i)oRest[\t ]*:[\t ]*GetBodyRequest[\t ]*\(",
        r"(?i):[\t ]*FromJson[\t ]*\(",
        r'(?i)\[[\t ]*"message"[\t ]*\][\t ]*:=[\t ]*"Payload inválido\."',
        r'(?i)\[[\t ]*"status"[\t ]*\][\t ]*:=[\t ]*"error"',
        r"(?i)oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*400[\t ]*\)",
        r"(?i)oRest[\t ]*:[\t ]*SetStatusCode[\t ]*\([\t ]*200[\t ]*\)",
    ]:
        assert_match(post_validation, pattern, f"Contrato obrigatório ausente no endpoint HeloPost: {pattern}")

    forbidden = {
        r"(?i)oError[\t ]*:[\t ]*(Description|ErrorStack|Stack)": "Detalhes internos do erro não podem ser enviados ao cliente.",
        r"(?i)\btlpp\.doc\.generate[\t ]*\(": "Os endpoints de demonstração não podem depender de tlpp.doc.generate().",
        r"(?i)\b(FOpen|FCreate|FRead|FWrite|MemoRead|MemoWrite|Directory)[\t ]*\(": "Os endpoints de demonstração não podem depender de filesystem.",
    }
    for validation_content in (get_validation, post_validation):
        for pattern, message in forbidden.items():
            if re.search(pattern, validation_content):
                raise ContractError(message)


def check_global_forbidden_patterns():
    forbidden = {
        r"(?im)^[\t ]*Function[\t ]+": "Function não pode ser usado em customizações.",
        r"(?im)^[\t ]*User[\t ]+Function[\t ]+U_": "Não declare o prefixo U_ explicitamente.",
        r"(?i)\bcVer\b": "Identificador cVer proibido: conflito com macro cVer de sigawin.ch.",
        r"(?i)\btlpp\.doc\.generate[\t ]*\(": "O núcleo não pode depender de tlpp.doc.generate().",
        r"(?i)\b(FOpen|FCreate|FRead|FWrite|MemoRead|MemoWrite|Directory)[\t ]*\(": "O núcleo não pode depender de filesystem.",
    }

    source_roots = [
        REPO_ROOT / "src" / "core",
        REPO_ROOT / "tests" / "openapi-core",
        REPO_ROOT / "examples" / "openapi-core",
        REPO_ROOT / "examples" / "openapi-parameters-schemas",
    ]

    for source_root in source_roots:
        if not source_root.is_dir():
            continue
        for source in sorted(source_root.glob("*.tlpp")):
            content = get_cp1252_content(source)
            validation_content = strip_comments(content)
            for pattern, message in forbidden.items():
                if re.search(pattern, validation_content):
                    raise ContractError(f"{message} Fonte: {source}")


def main():
    try:
        for spec in _core_class_specs():
            check_class(spec)
        check_json_class()
        check_test_fixture()
        check_api_endpoint()
        check_hello_endpoints()
        check_global_forbidden_patterns()
    except ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Contrato do núcleo OpenAPI válido.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
