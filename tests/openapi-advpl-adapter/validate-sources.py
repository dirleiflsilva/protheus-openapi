#!/usr/bin/env python
"""Valida o contrato estatico do adaptador AdvPL (Fase 4 do roadmap, T2).

Espelha o padrao de tests/openapi-tlpp-adapter/validate-sources.py: includes,
namespace, ProtheusDoc por metodo/funcao, declaracao/implementacao por
metodo, contrato do fixture PROBAT e padroes proibidos globais do projeto.

Ao contrario do adaptador TL++ (que descobre servicos via reflection em
runtime e por isso NAO pode depender de filesystem), o adaptador AdvPL
existe justamente porque nao ha reflection equivalente para WSRESTFUL -
seu mecanismo e ler e parsear o texto-fonte. Por isso MemoRead()/MemoWrite()
sao exigidos aqui, e nao proibidos.
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


# --- OApiWsrParser (src/adapters/custom.openapi.adapter.advpl.parser.tlpp) -

def check_parser_class():
    path = REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.advpl.parser.tlpp"
    class_name = "OApiWsrParser"
    content = get_cp1252_content(path, f"Fonte {class_name} não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "totvs.ch"], class_name)

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.advpl[\t ]*\r?$",
        f"Namespace custom.openapi.adapter.advpl ausente no {class_name}.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*Using[\t ]+Namespace[\t ]+tlpp\.regex[\t ]*\r?$",
        f"Using Namespace tlpp.regex ausente no {class_name} (necessário para instanciar Regex()).",
    )
    assert_match(
        content,
        rf"(?im)^[\t ]*class[\t ]+{class_name}\b",
        f"Classe {class_name} ausente.",
    )

    methods = [
        {"name": "new", "patterns": [r"(?im)^[\t ]*@return[\t ]+object,[\t ]+[^\r\n]+\r?$"]},
        {
            "name": "parse",
            "patterns": [
                r"(?im)^[\t ]*@param[\t ]+cFilePath,[\t ]+character,[\t ]+[^\r\n]+\r?$",
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
            r"(?im)^[\t ]*@since[\t ]+2026-09-30\b",
        ]
        for pattern in trio + method["patterns"]:
            if not re.search(pattern, doc_body):
                raise ContractError(f"ProtheusDOC incompleto para {class_name}::{name}: {pattern}")

    assert_match(
        content,
        (
            rf"(?is)/\*/\{{Protheus\.doc\}}[\t ]+{class_name}\b.*?@type[\t ]+class\b.*?"
            rf"@author[\t ]+Dirlei Silva\b.*?@since[\t ]+2026-09-30\b.*?\*/[\t \r\n]*class[\t ]+{class_name}\b"
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

    for fn in ["FindPositions", "FindEndPositions", "NextToken", "ParseWsData", "ParseWsrService"]:
        assert_match(
            validation_content,
            rf"(?im)^[\t ]*Static[\t ]+Function[\t ]+{fn}[\t ]*\(",
            f"Função auxiliar privada {fn} ausente no {class_name}.",
        )

    for pattern, message in {
        r"(?i)MemoRead[\t ]*\(": "parse() deve ler o arquivo-fonte com MemoRead() - a plataforma não tem reflection para WSRESTFUL.",
        r"(?i)Regex[\t ]*\(\)[\t ]*:[\t ]*New[\t ]*\(": "O parser deve instanciar a classe Regex().",
        r"(?i):[\t ]*Tokenizer[\t ]*\(": "FindPositions() deve usar Regex():Tokenizer() para localizar ocorrências.",
        r'(?i)StrTran[\t ]*\([^\r\n]*";"': "parse() deve reunir continuações ';' antes de extrair tokens (ADVP-08).",
    }.items():
        assert_match(validation_content, pattern, message)


# --- Fixture PROBAT (tests/openapi-advpl-adapter/custom.openapi.advpl.adapter.test.tlpp)

def check_test_fixture():
    path = REPO_ROOT / "tests" / "openapi-advpl-adapter" / "custom.openapi.advpl.adapter.test.tlpp"
    content = get_cp1252_content(path, f"Fonte de teste não encontrado: {path}")

    check_includes(content, ["tlpp-core.th", "tlpp-probat.th", "totvs.ch"], "adaptador AdvPL")

    assert_match(
        content,
        r"(?m)^[\t ]*namespace[\t ]+custom\.openapi\.adapter\.advpl\.test[\t ]*\r?$",
        "Namespace custom.openapi.adapter.advpl.test ausente.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+tlpp\.probat[\t ]*\r?$",
        "Importação do namespace tlpp.probat ausente.",
    )
    assert_match(
        content,
        r"(?m)^[\t ]*using[\t ]+namespace[\t ]+custom\.openapi\.adapter\.advpl[\t ]*\r?$",
        "Importação do namespace custom.openapi.adapter.advpl ausente.",
    )

    fixture_match = re.search(
        (
            r"(?ms)(?P<doc>/\*/\{Protheus\.doc\}.*?\*/)[\t \r\n]*@TestFixture[\t ]*\([\t ]*\)[\t \r\n]*"
            r"User[\t ]+Function[\t ]+OApiWsrTst[\t ]*\([\t ]*\)[\t ]+as[\t ]+Logical[\t ]*\r?$"
        ),
        content,
    )
    if not fixture_match:
        raise ContractError("Sequência ProtheusDOC, @TestFixture() e User Function OApiWsrTst() ausente.")

    doc_body = fixture_match.group("doc")
    for pattern in [
        r"(?m)^[\t ]*@type[\t ]+function[\t ]*\r?$",
        r"(?m)^[\t ]*@author[\t ]+Dirlei Silva[\t ]*\r?$",
        r"(?m)^[\t ]*@since[\t ]+2026-09-30[\t ]*\r?$",
        r"(?m)^[\t ]*@return[\t ]+logical,[\t ]+[^\r\n]+\r?$",
    ]:
        assert_match(doc_body, pattern, f"ProtheusDOC obrigatório ausente no fixture: {pattern}")

    validation_content = strip_comments(content)

    min_asserts = len(re.findall(r"(?im)^[\t ]*assertEquals[\t ]*\(", validation_content))
    if min_asserts < 8:
        raise ContractError(f"O fixture deve ter no mínimo 8 asserções (encontradas {min_asserts}).")

    for pattern, message in {
        r'(?i)OApiWsrParser[\t ]*\([\t ]*\)[\t ]*:[\t ]*New[\t ]*\(': "O fixture deve instanciar OApiWsrParser.",
        r'(?i):[\t ]*parse[\t ]*\(': "O fixture deve chamar OApiWsrParser::parse().",
        r'(?i)"HelloAdvpl"': "O fixture deve validar o servico real HelloAdvpl do exemplo-alvo.",
        r'(?i)"language"': "O fixture deve validar o WSDATA language do exemplo-alvo.",
        r"(?im)^[\t ]*assertEquals[\t ]*\([\t ]*0[\t ]*,[\t ]*Len[\t ]*\(": "O fixture deve validar ao menos um caso de resultado vazio (sem bloco WSRESTFUL).",
        r'(?i)DESCRIPTION[\t ]+STR0001': "O fixture deve testar DESCRIPTION com constante simbólica.",
        r'(?i)WSDATA[\t ]+items[\t ]+AS[\t ]+ARRAY': "O fixture deve testar WSDATA de tipo não suportado (ARRAY).",
        r'(?i)Teste continuacao";': "O fixture deve testar a reunião de continuações ';' (ADVP-08).",
        r'(?i)MemoWrite[\t ]*\(': "O fixture deve escrever os cenários de texto embutido em arquivo antes de chamar parse().",
    }.items():
        assert_match(validation_content, pattern, message)


def check_global_forbidden_patterns():
    forbidden = {
        r"(?im)^[\t ]*Function[\t ]+": "Function não pode ser usado em customizações.",
        r"(?im)^[\t ]*User[\t ]+Function[\t ]+U_": "Não declare o prefixo U_ explicitamente.",
        r"(?i)\bcVer\b": "Identificador cVer proibido: conflito com macro cVer de sigawin.ch.",
        r"(?i)\btlpp\.doc\.generate[\t ]*\(": "O adaptador não pode depender de tlpp.doc.generate().",
        r"(?i)\bIIF[\t ]*\(": "IIF() é proibido; use If/Else/EndIf.",
    }

    source_roots = [
        REPO_ROOT / "src" / "adapters" / "custom.openapi.adapter.advpl.parser.tlpp",
        REPO_ROOT / "tests" / "openapi-advpl-adapter" / "custom.openapi.advpl.adapter.test.tlpp",
    ]

    for source in source_roots:
        if not source.is_file():
            continue
        content = get_cp1252_content(source)
        validation_content = strip_comments(content)
        for pattern, message in forbidden.items():
            if re.search(pattern, validation_content):
                raise ContractError(f"{message} Fonte: {source}")


def main():
    try:
        check_parser_class()
        check_test_fixture()
        check_global_forbidden_patterns()
    except ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Contrato do adaptador AdvPL (T2) válido.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
