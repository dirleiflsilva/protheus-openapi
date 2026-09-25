#!/usr/bin/env python
"""Valida o contrato estatico do adaptador TL++ (Fase 3 do roadmap).

Espelha o padrao de tests/openapi-core/validate-sources.py: includes,
namespace, ProtheusDoc por metodo/classe, declaracao/implementacao por
metodo, contrato do fixture PROBAT e padroes proibidos globais do projeto.
"""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


class ContractError(Exception):
    pass


def get_cp1252_content(path: Path, not_found_message=None):
    if not path.is_file():
        raise ContractError(not_found_message or f"Fonte não encontrado: {path}")

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


# --- OApiAdpDsc (src/adapters/custom.openapi.adapter.discovery.tlpp) -------

def check_discovery_class():
    path = REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.discovery.tlpp"
    class_name = "OApiAdpDsc"
    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "totvs.ch"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.tlpp[\t ]*\r?$",
        "Namespace custom.openapi.adapter.tlpp ausente no OApiAdpDsc.",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    methods = [
        {
            "name": "new",
            "patterns": [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"],
        },
        {
            "name": "discover",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cVerb,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@param[\t ]+aSources,[\t ]+array,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$",
            ],
        },
    ]

    for method in methods:
        name = method["name"]
        doc_match = re.search(
            rf"(?is)(?P<doc>/\*/\{{Protheus\.doc\}}[\t ]+{class_name}::{name}\b.*?\*/)[\t \r\n]*method[\t ]+{name}[\t ]*\(",
            content,
        )
        if not doc_match:
            raise ContractError(f"ProtheusDOC obrigatório ausente para {class_name}::{name}.")

        doc_body = doc_match.group("doc")
        trio = [
            r"(?im)^[\t ]*@type[\t ]+method\b",
            r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
            r"(?im)^[\t ]*@since[\t ]+2026-09-25\b",
        ]
        for pattern in trio + method["patterns"]:
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-09-25\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
        ),
        f"ProtheusDOC obrigatório ausente para a classe {class_name}.",
    )

    validation_content = strip_comments(content)

    for method in methods:
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

    for pattern, message in {
        r"(?i)Reflection[\t ]*\.[\t ]*getFunctionsByAnnotation[\t ]*\(": "discover() deve chamar Reflection.getFunctionsByAnnotation().",
        r"(?i)Reflection[\t ]*\.[\t ]*getFunctionAnnotation[\t ]*\(": "discover() deve chamar Reflection.getFunctionAnnotation().",
    }.items():
        assert_match(validation_content, pattern, message)


# --- OApiAdpPath (src/adapters/custom.openapi.adapter.path.tlpp) -----------

def check_path_class():
    path = REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.path.tlpp"
    class_name = "OApiAdpPath"
    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "totvs.ch"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.tlpp[\t ]*\r?$",
        f"Namespace custom.openapi.adapter.tlpp ausente no {class_name}.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.core[\t ]*\r?$",
        f"Importação do namespace custom.openapi.core ausente no {class_name}.",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    methods = [
        {"name": "new", "patterns": [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]},
        {
            "name": "toTemplate",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cEndpoint,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+character,[\t ]+[^\r\n]+\r?$",
            ],
        },
        {
            "name": "toParams",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cEndpoint,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$",
            ],
        },
    ]

    for method in methods:
        name = method["name"]
        doc_match = re.search(
            rf"(?is)(?P<doc>/\*/\{{Protheus\.doc\}}[\t ]+{class_name}::{name}\b.*?\*/)[\t \r\n]*method[\t ]+{name}[\t ]*\(",
            content,
        )
        if not doc_match:
            raise ContractError(f"ProtheusDOC obrigatório ausente para {class_name}::{name}.")

        doc_body = doc_match.group("doc")
        trio = [
            r"(?im)^[\t ]*@type[\t ]+method\b",
            r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
            r"(?im)^[\t ]*@since[\t ]+2026-09-25\b",
        ]
        for pattern in trio + method["patterns"]:
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-09-25\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
        ),
        f"ProtheusDOC obrigatório ausente para a classe {class_name}.",
    )

    validation_content = strip_comments(content)

    for method in methods:
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

    for pattern, message in {
        r'(?i)OApiSchema[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([\t ]*"string"': "toParams() deve gerar schema string para o parametro de path.",
        r'(?i)OApiParam[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\([^\r\n]*"path"': "toParams() deve gerar OApiParam com in='path'.",
    }.items():
        assert_match(validation_content, pattern, message)


# --- OApiAdpMeta (src/adapters/custom.openapi.adapter.metadata.tlpp) -------

def check_metadata_class():
    path = REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.metadata.tlpp"
    class_name = "OApiAdpMeta"
    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "totvs.ch"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.tlpp[\t ]*\r?$",
        f"Namespace custom.openapi.adapter.tlpp ausente no {class_name}.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.core[\t ]*\r?$",
        f"Importação do namespace custom.openapi.core ausente no {class_name}.",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    methods = [
        {"name": "new", "patterns": [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]},
        {
            "name": "toQueryParams",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cParamsJson,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+array,[\t ]+[^\r\n]+\r?$",
            ],
        },
        {
            "name": "toBody",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cBodyJson,[\t ]+character,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
            ],
        },
    ]

    for method in methods:
        name = method["name"]
        doc_match = re.search(
            rf"(?is)(?P<doc>/\*/\{{Protheus\.doc\}}[\t ]+{class_name}::{name}\b.*?\*/)[\t \r\n]*method[\t ]+{name}[\t ]*\(",
            content,
        )
        if not doc_match:
            raise ContractError(f"ProtheusDOC obrigatório ausente para {class_name}::{name}.")

        doc_body = doc_match.group("doc")
        trio = [
            r"(?im)^[\t ]*@type[\t ]+method\b",
            r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
            r"(?im)^[\t ]*@since[\t ]+2026-09-25\b",
        ]
        for pattern in trio + method["patterns"]:
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-09-25\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
        ),
        f"ProtheusDOC obrigatório ausente para a classe {class_name}.",
    )

    validation_content = strip_comments(content)

    for method in methods:
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

    for pattern, message in {
        r'(?i)OApiSchema[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "toQueryParams()/toBody() devem instanciar OApiSchema.",
        r'(?i)OApiParam[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "toQueryParams() deve instanciar OApiParam.",
        r'(?i)OApiBody[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "toBody() deve instanciar OApiBody.",
        r"(?i):[\t ]*FromJson[\t ]*\(": "toQueryParams()/toBody() devem usar JsonObject:FromJson().",
        r'(?i):[\t ]*setRef[\t ]*\(': "toBody() deve chamar setRef() no schema do requestBody.",
    }.items():
        assert_match(validation_content, pattern, message)


# --- OApiAdpBuild (src/adapters/custom.openapi.adapter.build.tlpp) ---------

def check_build_class():
    path = REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.build.tlpp"
    class_name = "OApiAdpBuild"
    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "totvs.ch"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.tlpp[\t ]*\r?$",
        f"Namespace custom.openapi.adapter.tlpp ausente no {class_name}.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.core[\t ]*\r?$",
        f"Importação do namespace custom.openapi.core ausente no {class_name}.",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    methods = [
        {"name": "new", "patterns": [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]},
        {
            "name": "build",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+oDoc,[\t ]+object,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@param[\t ]+aVerbs,[\t ]+array,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@param[\t ]+aSources,[\t ]+array,[\t ]+[^\r\n]+\r?$",
                r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$",
            ],
        },
    ]

    for method in methods:
        name = method["name"]
        doc_match = re.search(
            rf"(?is)(?P<doc>/\*/\{{Protheus\.doc\}}[\t ]+{class_name}::{name}\b.*?\*/)[\t \r\n]*method[\t ]+{name}[\t ]*\(",
            content,
        )
        if not doc_match:
            raise ContractError(f"ProtheusDOC obrigatório ausente para {class_name}::{name}.")

        doc_body = doc_match.group("doc")
        trio = [
            r"(?im)^[\t ]*@type[\t ]+method\b",
            r"(?im)^[\t ]*@author[\t ]+Dirlei Silva\b",
            r"(?im)^[\t ]*@since[\t ]+2026-09-25\b",
        ]
        for pattern in trio + method["patterns"]:
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-09-25\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
        ),
        f"ProtheusDOC obrigatório ausente para a classe {class_name}.",
    )

    validation_content = strip_comments(content)

    for method in methods:
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

    for pattern, message in {
        r'(?i)OApiAdpDsc[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "build() deve instanciar OApiAdpDsc.",
        r'(?i)OApiAdpPath[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "build() deve instanciar OApiAdpPath.",
        r'(?i)OApiAdpMeta[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "build() deve instanciar OApiAdpMeta.",
        r'(?i)OApiOper[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "build() deve instanciar OApiOper.",
        r'(?i)OApiPath[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "build() deve instanciar OApiPath.",
        r'(?i):[\t ]*addPath[\t ]*\(': "build() deve chamar oDoc:addPath().",
        r'(?i):[\t ]*addOper[\t ]*\(': "build() deve chamar oPath:addOper().",
    }.items():
        assert_match(validation_content, pattern, message)


# --- Fixture PROBAT (tests/openapi-tlpp-adapter/custom.openapi.tlpp.adapter.test.tlpp)

def check_test_fixture():
    path = REPO_ROOT / "tests" / "openapi-tlpp-adapter" / "custom.openapi.tlpp.adapter.test.tlpp"
    content = get_cp1252_content(path, f"Fonte de teste não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "tlpp-probat.th", "totvs.ch"], "adaptador TL++")

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.tlpp\.test[\t ]*\r?$",
        "Namespace custom.openapi.adapter.tlpp.test ausente.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+tlpp\.probat[\t ]*\r?$",
        "Importação do namespace tlpp.probat ausente.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.adapter\.tlpp[\t ]*\r?$",
        "Importação do namespace custom.openapi.adapter.tlpp ausente.",
    )

    fixture_match = re.search(
        (
            r"(?ms)(?P<doc>/\*/\{Protheus\.doc\}.*?\*/)[\t \r\n]*@TestFixture[\t ]*\([\t ]*\)[\t \r\n]*"
            r"User[\t ]+Function[\t ]+OApiAdpTst[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$"
        ),
        content,
    )
    if not fixture_match:
        raise ContractError("Sequência ProtheusDOC, @TestFixture() e User Function OApiAdpTst() ausente.")

    doc_body = fixture_match.group("doc")
    for pattern in [
        r"(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$",
        r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
        r"(?m)^[\t ]*@since[\t ]+2026-09-25[\t ]*\r?$",
        r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$",
    ]:
        assert_match(doc_body, pattern, f"ProtheusDOC obrigatório ausente no fixture: {pattern}")

    validation_content = strip_comments(content)

    for pattern, message in {
        r'(?i)OApiAdpDsc[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "O fixture deve instanciar OApiAdpDsc.",
        r'(?i):[\t ]*discover[\t ]*\([\t ]*"Get"': "O fixture deve testar a descoberta do verbo Get.",
        r'(?i):[\t ]*discover[\t ]*\([\t ]*"Post"': "O fixture deve testar a descoberta do verbo Post.",
        r'(?i)"U_HELOGET"': "O fixture deve validar o cFunctionName real de HeloGet (U_HELOGET).",
        r'(?i)"U_HELOPOST"': "O fixture deve validar o cFunctionName real de HeloPost (U_HELOPOST).",
        r"(?im)^[\t ]*assertEquals[\t ]*\([\t ]*0[\t ]*,[\t ]*Len[\t ]*\(": "O fixture deve validar ao menos um caso de descoberta vazia (verbo ou fonte sem correspondência).",
        r'(?i)OApiAdpPath[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "O fixture deve instanciar OApiAdpPath.",
        r'(?i):[\t ]*toTemplate[\t ]*\(': "O fixture deve testar toTemplate().",
        r'(?i):[\t ]*toParams[\t ]*\(': "O fixture deve testar toParams().",
        r'(?i)"/api/v1/hello/\{name\}"': "O fixture deve validar o template OpenAPI gerado para o path com :name.",
        r'(?i)OApiAdpMeta[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "O fixture deve instanciar OApiAdpMeta.",
        r'(?i):[\t ]*toQueryParams[\t ]*\(': "O fixture deve testar toQueryParams().",
        r'(?i):[\t ]*toBody[\t ]*\(': "O fixture deve testar toBody().",
        r'(?i)"HelloRequest"': "O fixture deve validar a referencia HelloRequest no requestBody descoberto.",
        r'(?i)OApiAdpBuild[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "O fixture deve instanciar OApiAdpBuild.",
        r'(?i):[\t ]*build[\t ]*\(': "O fixture deve chamar OApiAdpBuild::build().",
        r'(?i):[\t ]*getPaths[\t ]*\(': "O fixture deve verificar oFullDoc:getPaths() apos a montagem automatica.",
        r'(?i):[\t ]*validate[\t ]*\(': "O fixture deve validar o documento montado automaticamente (oFullDoc:validate()).",
        r"(?im)^[\t ]*Try[\t ]*\r?$": "O fixture deve testar o caso de path duplicado com Try/Catch.",
    }.items():
        assert_match(validation_content, pattern, message)


def check_global_forbidden_patterns():
    forbidden = {
        r"(?im)^[\t ]*Function[\t ]+": "Function não pode ser usado em customizações.",
        r"(?im)^[\t ]*User[\t ]+Function[\t ]+U_": "Não declare o prefixo U_ explicitamente.",
        r"(?i)\bcVer\b": "Identificador cVer proibido: conflito com macro cVer de sigawin.ch.",
        r"(?i)\btlpp\.doc\.generate[\t ]*\(": "O adaptador não pode depender de tlpp.doc.generate().",
        r"(?i)\b(FOpen|FCreate|FRead|FWrite|MemoRead|MemoWrite|Directory)[\t ]*\(": "O adaptador não pode depender de filesystem.",
        r"(?i)\bIIF[\t ]*\(": "IIF() é proibido; use If/Else/EndIf.",
    }

    source_roots = [
        REPO_ROOT / "src" / "adapters",
        REPO_ROOT / "tests" / "openapi-tlpp-adapter",
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
        check_discovery_class()
        check_path_class()
        check_metadata_class()
        check_build_class()
        check_test_fixture()
        check_global_forbidden_patterns()
    except ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Contrato do adaptador TL++ válido.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
