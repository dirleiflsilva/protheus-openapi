#!/usr/bin/env python
"""Consolida path items OpenAPI duplicados dentro da secao paths de um YAML.

Porte de normalize-openapi-paths.ps1. Assim como o original, este e um
sub-parser YAML restrito a pares "chave: valor" indentados apenas com
espacos (2 espacos por nivel) - nao um parser YAML completo.
"""
import argparse
import os
import re
import sys
import uuid
from pathlib import Path

_KEY_VALUE_RE = re.compile(r"^(?P<spaces> *)(?P<key>'[^']*'|\"[^\"]*\"|[^:#][^:]*?):[ ]*(?P<value>.*)$")
_HTTP_METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}


class NormalizeError(Exception):
    pass


def _yaml_scalar(value):
    result = value.strip()
    if len(result) >= 2 and result[0] == "'" and result[-1] == "'":
        return result[1:-1].replace("''", "'")
    if len(result) >= 2 and result[0] == '"' and result[-1] == '"':
        return result[1:-1]
    return result


def _is_http_method(name):
    return name in _HTTP_METHODS


class _Entry:
    __slots__ = ("key", "indent", "line", "value")

    def __init__(self, key, indent, line, value):
        self.key = key
        self.indent = indent
        self.line = line
        self.value = value


def _key_entry(line, line_number):
    match = _KEY_VALUE_RE.match(line)
    if not match:
        return None
    return _Entry(
        key=_yaml_scalar(match.group("key")),
        indent=len(match.group("spaces")),
        line=line_number,
        value=match.group("value"),
    )


def _read_openapi_text(path: Path) -> str:
    data = path.read_bytes()
    offset = 3 if data[:3] == b"\xef\xbb\xbf" else 0
    try:
        return data[offset:].decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        return data.decode("cp1252")


def _block_children(lines, start, end):
    starts = []
    for index in range(start + 1, end + 1):
        entry = _key_entry(lines[index], index + 1)
        if entry is not None and entry.indent == 4:
            starts.append(index)

    children = []
    for child_index, child_start in enumerate(starts):
        child_end = starts[child_index + 1] - 1 if child_index + 1 < len(starts) else end
        entry = _key_entry(lines[child_start], child_start + 1)
        children.append({"key": entry.key, "line": entry.line, "lines": lines[child_start : child_end + 1]})
    return children


def _path_blocks(lines, paths_start, paths_end):
    starts = []
    for index in range(paths_start + 1, paths_end + 1):
        entry = _key_entry(lines[index], index + 1)
        if entry is not None and entry.indent == 2:
            starts.append(index)

    blocks = []
    for path_index, path_start in enumerate(starts):
        path_end = starts[path_index + 1] - 1 if path_index + 1 < len(starts) else paths_end
        entry = _key_entry(lines[path_start], path_start + 1)
        blocks.append(
            {
                "key": entry.key,
                "line": entry.line,
                "start": path_start,
                "end": path_end,
                "header": lines[path_start],
                "children": _block_children(lines, path_start, path_end),
            }
        )
    return blocks


def _join_compatible_path_blocks(blocks, document_lines):
    result = [blocks[0]["header"]]

    first_child_start = blocks[0]["end"] + 1
    if blocks[0]["children"]:
        first_child_start = blocks[0]["children"][0]["line"] - 1
    if first_child_start > blocks[0]["start"] + 1:
        result.extend(document_lines[blocks[0]["start"] + 1 : first_child_start])

    seen = {}
    operations_added = 0
    for block_index, block in enumerate(blocks):
        for child in block["children"]:
            signature = "\n".join(child["lines"])
            if child["key"] in seen:
                previous = seen[child["key"]]
                if _is_http_method(child["key"]):
                    raise NormalizeError(
                        f"O path '{blocks[0]['key']}' repete o verbo '{child['key']}' nas linhas "
                        f"{previous['line']} e {child['line']}."
                    )
                if previous["signature"] == signature:
                    continue
                raise NormalizeError(
                    f"O path '{blocks[0]['key']}' contém o campo compartilhado '{child['key']}' "
                    f"incompatível nas linhas {previous['line']} e {child['line']}."
                )

            seen[child["key"]] = {"line": child["line"], "signature": signature}
            if block_index > 0 and _is_http_method(child["key"]):
                operations_added += 1
            result.extend(child["lines"])

    return result, operations_added


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, dest="input_path")
    parser.add_argument("--output", required=True, dest="output_path")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)

    input_path = Path(args.input_path)
    if not input_path.is_file():
        print(f"Arquivo OpenAPI não encontrado: {input_path}", file=sys.stderr)
        return 1

    input_full = input_path.resolve()
    output_full = Path(args.output_path).resolve()

    if str(input_full).lower() == str(output_full).lower():
        print("Os caminhos de entrada e saída devem ser diferentes.", file=sys.stderr)
        return 1

    if output_full.is_file() and not args.force:
        print(
            f"O arquivo de saída já existe. Use --force para permitir a substituição: {output_full}",
            file=sys.stderr,
        )
        return 1

    content = _read_openapi_text(input_full)
    if not content.strip():
        print(f"O arquivo OpenAPI está vazio: {input_full}", file=sys.stderr)
        return 1

    newline = "\r\n" if "\r\n" in content else "\n"
    document_lines = re.split(r"\r?\n", content)

    for index, line in enumerate(document_lines):
        if "\t" in line:
            print(
                f"O YAML contém tabulação na linha {index + 1}; use somente espaços para indentação.",
                file=sys.stderr,
            )
            return 1

    root_entries = []
    for index, line in enumerate(document_lines):
        entry = _key_entry(line, index + 1)
        if entry is not None and entry.indent == 0:
            root_entries.append((entry, index))

    paths_roots = [(entry, index) for entry, index in root_entries if entry.key == "paths"]
    if len(paths_roots) != 1:
        print(
            f"O YAML deve conter exatamente uma seção raiz paths. Encontrado: {len(paths_roots)}.",
            file=sys.stderr,
        )
        return 1

    paths_start = paths_roots[0][1]
    paths_end = len(document_lines) - 1
    later_roots = [index for _, index in root_entries if index > paths_start]
    if later_roots:
        paths_end = min(later_roots) - 1

    try:
        path_blocks = _path_blocks(document_lines, paths_start, paths_end)
    except NormalizeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    output_lines = list(document_lines[: paths_start + 1])

    if path_blocks and path_blocks[0]["start"] > paths_start + 1:
        output_lines.extend(document_lines[paths_start + 1 : path_blocks[0]["start"]])

    processed = set()
    groups_merged = 0
    operations_added = 0
    try:
        for path_block in path_blocks:
            if path_block["key"] in processed:
                continue
            processed.add(path_block["key"])

            matches = [block for block in path_blocks if block["key"] == path_block["key"]]
            if len(matches) == 1:
                output_lines.extend(document_lines[path_block["start"] : path_block["end"] + 1])
                continue

            groups_merged += 1
            merged_lines, added = _join_compatible_path_blocks(matches, document_lines)
            operations_added += added
            output_lines.extend(merged_lines)
    except NormalizeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if paths_end + 1 < len(document_lines):
        output_lines.extend(document_lines[paths_end + 1 :])

    output_content = newline.join(output_lines)

    output_full.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_full.parent / f".{output_full.name}.{uuid.uuid4().hex}.tmp"
    try:
        with open(temp_path, "w", encoding="utf-8", newline="") as handle:
            handle.write(output_content)
        os.replace(temp_path, output_full)
    finally:
        if temp_path.exists():
            temp_path.unlink()

    print(
        f"Normalização concluída. Declarações: {len(path_blocks)}; Paths únicos: {len(processed)}; "
        f"Grupos consolidados: {groups_merged}; Operações incorporadas: {operations_added}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
