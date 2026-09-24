#!/usr/bin/env python
"""Suite de testes para scripts/normalize-openapi-paths.py.

Porte de tests/openapi-normalization/run-tests.ps1. Cada teste que espera
falha invoca o normalizador como subprocesso (novo interpretador Python),
assim como o original invocava um novo powershell.exe - garante que o
codigo de saida e as mensagens de erro observados sao os mesmos que um
usuario real veria rodando o script isoladamente.
"""
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
NORMALIZER = REPO_ROOT / "scripts" / "normalize-openapi-paths.py"
FIXTURES = Path(__file__).resolve().parent / "fixtures"

_passed = 0
_failed = 0


class AssertionFailedError(Exception):
    pass


def assert_true(condition, message):
    if not condition:
        raise AssertionFailedError(message)


def assert_match_count(content, pattern, expected, message):
    import re

    actual = len(re.findall(pattern, content))
    if actual != expected:
        raise AssertionFailedError(f"{message} Esperado: {expected}; obtido: {actual}.")


def run_normalizer(fixture, output):
    if not NORMALIZER.is_file():
        raise AssertionFailedError(f"Normalizador não encontrado: {NORMALIZER}")
    result = subprocess.run(
        [sys.executable, str(NORMALIZER), "--input", str(FIXTURES / fixture), "--output", str(output)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise AssertionFailedError(f"Normalização de {fixture} falhou inesperadamente: {result.stderr.strip()}")


def run_normalizer_process(input_file, output, force=False):
    args = [sys.executable, str(NORMALIZER), "--input", str(input_file), "--output", str(output)]
    if force:
        args.append("--force")
    result = subprocess.run(args, capture_output=True, text=True)
    message = (result.stdout or "") + (result.stderr or "")
    return result.returncode, message


def run_normalizer_failure(fixture, output):
    return run_normalizer_process(FIXTURES / fixture, output)


def assert_utf8_without_bom(path):
    data = Path(path).read_bytes()
    has_bom = data[:3] == b"\xef\xbb\xbf"
    assert_true(not has_bom, "A saída contém BOM.")
    try:
        data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise AssertionFailedError("A saída não é UTF-8 válida.") from exc


def invoke_test(name, body):
    global _passed, _failed
    try:
        body()
        _passed += 1
        print(f"PASS: {name}")
    except Exception as exc:  # noqa: BLE001 - mirror do catch genérico do PS
        _failed += 1
        print(f"FAIL: {name} - {exc}")


def main():
    temp_root = Path(tempfile.gettempdir()) / f"openapi-normalization-{uuid.uuid4().hex}"
    temp_root.mkdir(parents=True, exist_ok=True)

    try:
        def test_unique_path():
            output = temp_root / "unique.yaml"
            run_normalizer("unique-path.yaml", output)
            content = output.read_text(encoding="utf-8")
            assert_match_count(content, r"(?m)^  /api/items:\r?$", 1, "Path único alterado.")
            assert_match_count(content, r"(?m)^    get:\r?$", 1, "Operação GET ausente.")
            assert_true("info:" in content, "Seção info ausente.")
            assert_true("components:" in content, "Seção components ausente.")

        invoke_test("preserva path único e seções externas", test_unique_path)

        def test_merge_two():
            output = temp_root / "two.yaml"
            run_normalizer("merge-two-methods.yaml", output)
            content = output.read_text(encoding="utf-8")
            assert_match_count(content, r"(?m)^  /api/items/\{id\}:\r?$", 1, "Path duplicado não consolidado.")
            assert_match_count(content, r"(?m)^    get:\r?$", 1, "Operação GET ausente.")
            assert_match_count(content, r"(?m)^    put:\r?$", 1, "Operação PUT ausente.")

        invoke_test("consolida duas ocorrências com métodos distintos", test_merge_two)

        def test_merge_three():
            output = temp_root / "three.yaml"
            run_normalizer("merge-three-methods.yaml", output)
            content = output.read_text(encoding="utf-8")
            get_index = content.find("    get:")
            post_index = content.find("    post:")
            delete_index = content.find("    delete:")
            assert_match_count(content, r"(?m)^  /api/orders:\r?$", 1, "Path triplicado não consolidado.")
            assert_true(
                0 <= get_index < post_index < delete_index,
                "Ordem dos métodos não preservada.",
            )

        invoke_test("consolida três ocorrências preservando a ordem", test_merge_three)

        def test_shared_identical():
            output = temp_root / "shared.yaml"
            run_normalizer("shared-identical.yaml", output)
            content = output.read_text(encoding="utf-8")
            assert_match_count(
                content, r"(?m)^  /api/customers/\{id\}:\r?$", 1, "Path com campo compartilhado não consolidado."
            )
            assert_match_count(content, r"(?m)^    parameters:\r?$", 1, "Campo compartilhado não foi deduplicado.")
            assert_match_count(content, r"(?m)^    get:\r?$", 1, "Operação GET ausente.")
            assert_match_count(content, r"(?m)^    patch:\r?$", 1, "Operação PATCH ausente.")

        invoke_test("mantém uma cópia de campo compartilhado idêntico", test_shared_identical)

        def test_duplicate_method():
            output = temp_root / "duplicate-method.yaml"
            exit_code, message = run_normalizer_failure("duplicate-method.yaml", output)
            assert_true(exit_code != 0, "Verbo repetido foi aceito.")
            assert_true("/api/items/{id}" in message, "Diagnóstico não informa o path.")
            assert_true("get" in message, "Diagnóstico não informa o verbo.")
            assert_true("7" in message and "12" in message, "Diagnóstico não informa as linhas do verbo.")
            assert_true(not output.exists(), "Falha deixou arquivo de saída.")

        invoke_test("rejeita o mesmo verbo repetido", test_duplicate_method)

        def test_shared_conflict():
            output = temp_root / "shared-conflict.yaml"
            exit_code, message = run_normalizer_failure("shared-conflict.yaml", output)
            assert_true(exit_code != 0, "Campo compartilhado conflitante foi aceito.")
            assert_true("/api/customers/{id}" in message, "Diagnóstico não informa o path.")
            assert_true("parameters" in message, "Diagnóstico não informa o campo.")
            assert_true("7" in message and "14" in message, "Diagnóstico não informa as linhas do campo.")
            assert_true(not output.exists(), "Falha deixou arquivo de saída.")

        invoke_test("rejeita campo compartilhado incompatível", test_shared_conflict)

        def test_without_paths():
            output = temp_root / "without-paths.yaml"
            exit_code, message = run_normalizer_failure("without-paths.yaml", output)
            assert_true(exit_code != 0, "Documento sem paths foi aceito.")
            assert_true(
                "exatamente uma seção raiz paths" in message, "Diagnóstico inesperado para ausência de paths."
            )
            assert_true(not output.exists(), "Falha deixou arquivo de saída.")

        invoke_test("rejeita ausência da seção paths", test_without_paths)

        def test_duplicate_root_paths():
            output = temp_root / "duplicate-root-paths.yaml"
            exit_code, message = run_normalizer_failure("duplicate-root-paths.yaml", output)
            assert_true(exit_code != 0, "Documento com duas seções paths foi aceito.")
            assert_true("Encontrado: 2" in message, "Diagnóstico não informa duas seções paths.")
            assert_true(not output.exists(), "Falha deixou arquivo de saída.")

        invoke_test("rejeita duas seções raiz paths", test_duplicate_root_paths)

        def test_tab_indentation():
            output = temp_root / "tab-indentation.yaml"
            exit_code, message = run_normalizer_failure("tab-indentation.yaml", output)
            assert_true(exit_code != 0, "Tabulação foi aceita.")
            assert_true(
                "tabulação" in message and "linha 7" in message, "Diagnóstico não informa a linha com tabulação."
            )
            assert_true(not output.exists(), "Falha deixou arquivo de saída.")

        invoke_test("rejeita tabulação na estrutura", test_tab_indentation)

        cedilla, tilde_a, acute_i = "ç", "ã", "í"
        expected_title = f"Descri{cedilla}{tilde_a}o da a{cedilla}{tilde_a}o"
        expected_description = f"A{cedilla}{tilde_a}o conclu{acute_i}da"
        encoding_sample = (
            "openapi: 3.0.3\n"
            "info:\n"
            f"  title: {expected_title}\n"
            "  version: 1.0.0\n"
            "paths:\n"
            "  /api/encoding:\n"
            "    get:\n"
            f"      description: {expected_description}"
        )

        def test_utf8_with_and_without_bom():
            utf8_no_bom_input = temp_root / "utf8-no-bom-input.yaml"
            utf8_bom_input = temp_root / "utf8-bom-input.yaml"
            utf8_no_bom_output = temp_root / "utf8-no-bom-output.yaml"
            utf8_bom_output = temp_root / "utf8-bom-output.yaml"
            utf8_no_bom_input.write_text(encoding_sample, encoding="utf-8")
            with open(utf8_bom_input, "w", encoding="utf-8-sig") as handle:
                handle.write(encoding_sample)

            first_code, _ = run_normalizer_process(utf8_no_bom_input, utf8_no_bom_output)
            second_code, _ = run_normalizer_process(utf8_bom_input, utf8_bom_output)

            assert_true(first_code == 0 and second_code == 0, "Entrada UTF-8 foi rejeitada.")
            assert_true(
                expected_title in utf8_no_bom_output.read_text(encoding="utf-8"),
                "Acentos do UTF-8 sem BOM foram alterados.",
            )
            assert_true(
                expected_description in utf8_bom_output.read_text(encoding="utf-8"),
                "Acentos do UTF-8 com BOM foram alterados.",
            )

        invoke_test("aceita UTF-8 com e sem BOM", test_utf8_with_and_without_bom)

        def test_cp1252_input():
            input_path = temp_root / "cp1252-input.yaml"
            output = temp_root / "cp1252-output.yaml"
            input_path.write_bytes(encoding_sample.encode("cp1252"))

            exit_code, _ = run_normalizer_process(input_path, output)
            content = output.read_text(encoding="utf-8")

            assert_true(exit_code == 0, "Entrada CP1252 foi rejeitada.")
            assert_true(expected_title in content, "Acentos do CP1252 não foram preservados.")
            assert_true(expected_description in content, "Conteúdo CP1252 foi corrompido.")
            assert_utf8_without_bom(output)

        invoke_test("aceita CP1252 e publica UTF-8 sem BOM", test_cp1252_input)

        def test_same_input_output():
            input_path = temp_root / "same-path.yaml"
            shutil.copy(FIXTURES / "unique-path.yaml", input_path)
            before = input_path.read_bytes()

            exit_code, message = run_normalizer_process(input_path, input_path)

            assert_true(exit_code != 0, "Entrada e saída iguais foram aceitas.")
            assert_true(
                "caminhos de entrada e saída" in message, "Diagnóstico inesperado para caminhos iguais."
            )
            assert_true(input_path.read_bytes() == before, "Arquivo de entrada foi alterado.")

        invoke_test("rejeita entrada e saída iguais", test_same_input_output)

        def test_existing_without_force():
            output = temp_root / "existing.yaml"
            output.write_text("conteúdo original", encoding="utf-8")

            exit_code, message = run_normalizer_process(FIXTURES / "unique-path.yaml", output)

            assert_true(exit_code != 0, "Destino existente foi substituído sem Force.")
            assert_true("--force" in message, "Diagnóstico inesperado para destino existente.")
            assert_true(output.read_text(encoding="utf-8") == "conteúdo original", "Destino existente foi alterado.")

        invoke_test("protege destino existente sem Force", test_existing_without_force)

        def test_existing_with_force():
            output = temp_root / "forced.yaml"
            output.write_text("conteúdo original", encoding="utf-8")

            exit_code, _ = run_normalizer_process(FIXTURES / "unique-path.yaml", output, force=True)
            content = output.read_text(encoding="utf-8")

            assert_true(exit_code == 0, "Substituição com Force falhou.")
            assert_true("/api/items:" in content, "Destino não recebeu o YAML normalizado.")
            assert_utf8_without_bom(output)

        invoke_test("substitui destino atomicamente com Force", test_existing_with_force)

        def test_summary_and_cleanup():
            output = temp_root / "summary.yaml"
            exit_code, message = run_normalizer_process(FIXTURES / "merge-three-methods.yaml", output)

            assert_true(exit_code == 0, "Normalização para resumo falhou.")
            for label in ("Declarações", "Paths únicos", "Grupos consolidados", "Operações incorporadas"):
                assert_true(label in message, f"Resumo não contém '{label}'.")

            temporary_files = [
                path for path in temp_root.iterdir() if path.is_file() and path.name.startswith(".") and
                (path.name.endswith(".tmp") or path.name.endswith(".bak"))
            ]
            assert_true(len(temporary_files) == 0, "Arquivos temporários permaneceram após sucesso.")

        invoke_test("emite resumo e remove temporários", test_summary_and_cleanup)
    finally:
        if temp_root.is_dir():
            shutil.rmtree(temp_root, ignore_errors=True)

    print(f"Testes aprovados: {_passed}; falhas: {_failed}.")
    if _failed > 0:
        print(f"A suíte de normalização apresentou {_failed} falha(s).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
