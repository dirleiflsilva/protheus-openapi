#!/usr/bin/env python
"""Extrai um snapshot JSON sanitizado do documento OpenAPI Hello World.

Porte de extract-hello-openapi.ps1. Reutiliza o validador em
validate-hello-openapi.py (mesma pasta) carregado dinamicamente, para nao
duplicar as regras de contrato.
"""
import argparse
import importlib.util
import json
import os
import sys
import uuid
from pathlib import Path


def _load_validator():
    validator_path = Path(__file__).with_name("validate-hello-openapi.py")
    spec = importlib.util.spec_from_file_location("validate_hello_openapi", validator_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, dest="input_path")
    parser.add_argument("--output", required=True, dest="output_path")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)

    validator = _load_validator()

    try:
        contract = validator.load_contract(Path(args.input_path))
    except validator.ContractError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    input_full = Path(args.input_path).resolve()
    output_full = Path(args.output_path).resolve()

    if str(input_full).lower() == str(output_full).lower():
        print("Os caminhos de entrada e saída devem ser diferentes.", file=sys.stderr)
        return 1

    if output_full.is_dir():
        print(f"O caminho de saída aponta para um diretório: {output_full}", file=sys.stderr)
        return 1

    if output_full.is_file() and not args.force:
        print(
            f"O arquivo de saída já existe. Use --force para permitir a substituição: {output_full}",
            file=sys.stderr,
        )
        return 1

    safe_info = {}
    if contract["InfoTitle"].strip():
        safe_info["title"] = contract["InfoTitle"]
    if contract["InfoVersion"].strip():
        safe_info["version"] = contract["InfoVersion"]

    safe_operation = {
        contract["TitleField"]: contract["Title"],
        "description": contract["Description"],
        "responses": {"200": {"description": contract["ResponseDescription"]}},
    }

    snapshot = {
        contract["SpecField"]: contract["SpecVersion"],
        "info": safe_info,
        "paths": {contract["HelloPath"]: {"get": safe_operation}},
    }

    output_full.parent.mkdir(parents=True, exist_ok=True)

    temp_path = output_full.parent / f".{output_full.name}.{uuid.uuid4().hex}.tmp"
    try:
        with open(temp_path, "w", encoding="utf-8", newline="") as handle:
            json.dump(snapshot, handle, ensure_ascii=False, indent=2)
        os.replace(temp_path, output_full)
    finally:
        if temp_path.exists():
            temp_path.unlink()

    print(f"Snapshot JSON sanitizado criado em {output_full}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
