#!/usr/bin/env python
"""Valida o contrato minimo do documento OpenAPI Hello World (JSON ou YAML).

Porte de validate-hello-openapi.ps1. O parser YAML aqui e um sub-parser
proposital, restrito a pares "chave: valor" escalares indentados apenas com
espacos - nao substitui um parser YAML completo e nunca deve ser tratado
como tal.
"""
import argparse
import json
import re
import sys
from pathlib import Path

EXPECTED_TITLE = "Hello World"
EXPECTED_DESCRIPTION = "Retorna uma mensagem Hello World gerada por um endpoint TL++."
EXPECTED_RESPONSE_DESCRIPTION = "Hello World retornado com sucesso."

_HELLO_PATH_RE = re.compile(r"/api/v1/hello$")
_HELLO_TEMPLATE_RE = re.compile(r"/api/v1/hello/\{[^/{}]+\}$")
_KEY_VALUE_RE = re.compile(r"^(?P<spaces> *)(?P<key>'[^']*'|\"[^\"]*\"|[^:#][^:]*?):[ ]*(?P<value>.*)$")


class ContractError(Exception):
    pass


def _is_hello_candidate(key):
    return bool(_HELLO_PATH_RE.search(key) or _HELLO_TEMPLATE_RE.search(key))


def _test_spec_version(field, version):
    if field == "openapi" and not re.match(r"^3\.[0-9]+\.[0-9]+$", version):
        raise ContractError("A versão openapi deve ser uma string no formato 3.x.y.")
    if field == "swagger" and version != "2.0":
        raise ContractError("A versão swagger deve ser a string 2.0.")


# --- JSON ---------------------------------------------------------------

def read_json_contract(content):
    try:
        document = json.loads(content)
    except json.JSONDecodeError as exc:
        raise ContractError(f"Não foi possível interpretar o JSON OpenAPI: {exc}") from exc

    if not isinstance(document, dict):
        raise ContractError("A raiz do documento OpenAPI deve ser um objeto JSON.")

    has_openapi = "openapi" in document
    has_swagger = "swagger" in document
    if has_openapi == has_swagger:
        raise ContractError("O documento deve declarar exatamente uma versão em openapi ou swagger.")

    if has_openapi:
        value = document["openapi"]
        if not isinstance(value, str):
            raise ContractError("A versão openapi deve ser uma string no formato 3.x.y.")
        spec_field, spec_version = "openapi", value
    else:
        value = document["swagger"]
        if not isinstance(value, str):
            raise ContractError("A versão swagger deve ser a string 2.0.")
        spec_field, spec_version = "swagger", value

    _test_spec_version(spec_field, spec_version)

    paths = document.get("paths")
    if not isinstance(paths, dict):
        raise ContractError("O documento não contém um objeto paths válido.")

    candidates = [key for key in paths if _is_hello_candidate(key)]
    if not candidates:
        raise ContractError("Nenhum path terminado em /api/v1/hello ou /api/v1/hello/{param} foi encontrado.")

    get_matches = []
    for candidate in candidates:
        item = paths[candidate]
        if isinstance(item, dict) and isinstance(item.get("get"), dict):
            get_matches.append((candidate, item["get"]))

    if len(get_matches) != 1:
        raise ContractError(
            "Esperada exatamente uma operação GET em um path /api/v1/hello ou "
            f"/api/v1/hello/{{param}}; encontrada(s): {len(get_matches)}."
        )

    hello_path, operation = get_matches[0]

    title_field = None
    if ("title" in operation) != ("summary" in operation):
        title_field = "title" if "title" in operation else "summary"

    if title_field is None or operation[title_field] != EXPECTED_TITLE:
        raise ContractError("A operação deve declarar exatamente title ou summary com o valor Hello World.")

    if operation.get("description") != EXPECTED_DESCRIPTION:
        raise ContractError("Descrição inesperada para a operação Hello World.")

    responses = operation.get("responses")
    if not isinstance(responses, dict):
        raise ContractError("A operação GET não contém um objeto responses válido.")

    response_200 = responses.get("200")
    if not isinstance(response_200, dict):
        raise ContractError("A resposta HTTP 200 não foi documentada.")

    if response_200.get("description") != EXPECTED_RESPONSE_DESCRIPTION:
        raise ContractError("Descrição inesperada para a resposta HTTP 200.")

    info = document.get("info")
    info_title = ""
    info_version = ""
    if isinstance(info, dict):
        if isinstance(info.get("title"), str):
            info_title = info["title"]
        if isinstance(info.get("version"), str):
            info_version = info["version"]

    return {
        "SpecField": spec_field,
        "SpecVersion": spec_version,
        "InfoTitle": info_title,
        "InfoVersion": info_version,
        "HelloPath": hello_path,
        "TitleField": title_field,
        "Title": EXPECTED_TITLE,
        "Description": EXPECTED_DESCRIPTION,
        "ResponseDescription": EXPECTED_RESPONSE_DESCRIPTION,
    }


# --- YAML (sub-parser restrito) ------------------------------------------

class _YamlEntry:
    __slots__ = ("order", "line", "indent", "key", "value")

    def __init__(self, order, line, indent, key, value):
        self.order = order
        self.line = line
        self.indent = indent
        self.key = key
        self.value = value


def _yaml_scalar(value):
    result = value.strip()
    if len(result) >= 2 and result[0] == "'" and result[-1] == "'":
        return result[1:-1].replace("''", "'")
    if len(result) >= 2 and result[0] == '"' and result[-1] == '"':
        return result[1:-1]
    return result


def _get_yaml_entries(content):
    entries = []
    lines = re.split(r"\r?\n", content)
    for line_index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "" or stripped.startswith("#") or stripped == "---":
            continue
        if "\t" in line:
            raise ContractError(
                f"O YAML contém tabulação na linha {line_index + 1}; use somente espaços para indentação."
            )
        match = _KEY_VALUE_RE.match(line)
        if not match:
            continue
        entries.append(
            _YamlEntry(
                order=len(entries),
                line=line_index + 1,
                indent=len(match.group("spaces")),
                key=_yaml_scalar(match.group("key")),
                value=_yaml_scalar(match.group("value")),
            )
        )
    return entries


def _yaml_root_entries(entries):
    return [e for e in entries if e.indent == 0]


def _yaml_direct_children(entries, parent):
    descendants = []
    for entry in entries[parent.order + 1 :]:
        if entry.indent <= parent.indent:
            break
        descendants.append(entry)
    if not descendants:
        return []
    direct_indent = min(e.indent for e in descendants)
    return [e for e in descendants if e.indent == direct_indent]


def _exact_yaml_child(entries, parent, name):
    matches = [e for e in _yaml_direct_children(entries, parent) if e.key == name]
    return matches[0] if len(matches) == 1 else None


def read_yaml_contract(content):
    entries = _get_yaml_entries(content)
    roots = _yaml_root_entries(entries)

    version_entries = [e for e in roots if e.key in ("openapi", "swagger")]
    if len(version_entries) != 1:
        raise ContractError("O YAML deve declarar exatamente uma versão em openapi ou swagger.")

    spec_field = version_entries[0].key
    spec_version = version_entries[0].value
    _test_spec_version(spec_field, spec_version)

    paths_entries = [e for e in roots if e.key == "paths"]
    if len(paths_entries) != 1:
        raise ContractError("O YAML não contém uma seção paths válida.")

    path_entries = _yaml_direct_children(entries, paths_entries[0])

    grouped = {}
    for entry in path_entries:
        grouped.setdefault(entry.key, []).append(entry)
    duplicates = {key: group for key, group in grouped.items() if len(group) > 1}
    if duplicates:
        details = [
            f"{key} (linhas {', '.join(str(e.line) for e in group)})"
            for key, group in duplicates.items()
        ]
        raise ContractError(f"O YAML contém chaves de path duplicadas: {'; '.join(details)}.")

    candidates = [e for e in path_entries if _is_hello_candidate(e.key)]
    if not candidates:
        raise ContractError("Nenhum path terminado em /api/v1/hello ou /api/v1/hello/{param} foi encontrado.")

    get_matches = []
    for candidate in candidates:
        get_entry = _exact_yaml_child(entries, candidate, "get")
        if get_entry is not None:
            get_matches.append((candidate, get_entry))

    if len(get_matches) != 1:
        raise ContractError(
            "Esperada exatamente uma operação GET em um path /api/v1/hello ou "
            f"/api/v1/hello/{{param}}; encontrada(s): {len(get_matches)}."
        )

    hello_entry, get_entry = get_matches[0]

    title_entry = _exact_yaml_child(entries, get_entry, "title")
    summary_entry = _exact_yaml_child(entries, get_entry, "summary")
    title_candidates = [e for e in (title_entry, summary_entry) if e is not None]
    if len(title_candidates) != 1 or title_candidates[0].value != EXPECTED_TITLE:
        raise ContractError("A operação deve declarar exatamente title ou summary com o valor Hello World.")

    description_entry = _exact_yaml_child(entries, get_entry, "description")
    if description_entry is None or description_entry.value != EXPECTED_DESCRIPTION:
        raise ContractError("Descrição inesperada para a operação Hello World.")

    responses_entry = _exact_yaml_child(entries, get_entry, "responses")
    if responses_entry is None:
        raise ContractError("A operação GET não contém uma seção responses válida.")

    response_200_entry = _exact_yaml_child(entries, responses_entry, "200")
    if response_200_entry is None:
        raise ContractError("A resposta HTTP 200 não foi documentada.")

    response_description_entry = _exact_yaml_child(entries, response_200_entry, "description")
    if response_description_entry is None or response_description_entry.value != EXPECTED_RESPONSE_DESCRIPTION:
        raise ContractError("Descrição inesperada para a resposta HTTP 200.")

    info_title = ""
    info_version = ""
    info_entries = [e for e in roots if e.key == "info"]
    if len(info_entries) == 1:
        title_e = _exact_yaml_child(entries, info_entries[0], "title")
        if title_e is not None:
            info_title = title_e.value
        version_e = _exact_yaml_child(entries, info_entries[0], "version")
        if version_e is not None:
            info_version = version_e.value

    return {
        "SpecField": spec_field,
        "SpecVersion": spec_version,
        "InfoTitle": info_title,
        "InfoVersion": info_version,
        "HelloPath": hello_entry.key,
        "TitleField": title_candidates[0].key,
        "Title": EXPECTED_TITLE,
        "Description": EXPECTED_DESCRIPTION,
        "ResponseDescription": EXPECTED_RESPONSE_DESCRIPTION,
    }


# --- CLI -------------------------------------------------------------------

def load_contract(path: Path):
    if not path.is_file():
        raise ContractError(f"Arquivo OpenAPI não encontrado: {path}")

    try:
        raw = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        raise ContractError(f"Não foi possível ler o documento OpenAPI em '{path}': {exc}") from exc

    if not raw.strip():
        raise ContractError(f"O arquivo OpenAPI está vazio: {path}")

    suffix = path.suffix
    if suffix == ".yaml" or suffix == ".yml":
        return read_yaml_contract(raw)
    if suffix == ".json":
        return read_json_contract(raw)
    raise ContractError(f"Extensão OpenAPI não suportada: {suffix}. Use .yaml, .yml ou .json.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", required=True)
    parser.add_argument("--pass-thru", action="store_true", dest="pass_thru")
    parser.add_argument(
        "--json",
        action="store_true",
        help="Com --pass-thru, imprime o contrato como JSON (uso por outros scripts).",
    )
    args = parser.parse_args(argv)

    try:
        contract = load_contract(Path(args.path))
    except ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.pass_thru:
        if args.json:
            print(json.dumps(contract))
        else:
            print(contract)
        return 0

    print(f"OpenAPI válido para o experimento. Versão: {contract['SpecVersion']}; path: {contract['HelloPath']}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
