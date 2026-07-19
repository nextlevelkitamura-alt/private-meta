"""Manifest/result validation and output redaction without third-party packages."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROLES = {"explorer", "implementer", "evaluator"}
RUNTIMES = {"codex", "claude"}
PHASES = {"running", "implemented", "evaluated", "synced", "closed", "blocked"}
STATUSES = {"done", "blocked", "partial", "failed"}
TASK_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class ValidationError(ValueError):
    pass


SCHEMAS = Path(__file__).resolve().parent / "schemas"


def _require(value: dict[str, Any], keys: set[str], label: str) -> None:
    missing = keys - set(value)
    if missing:
        raise ValidationError(f"{label}の必須項目が無い: {', '.join(sorted(missing))}")


def _type_matches(value: Any, declared: str) -> bool:
    return {
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "null": value is None,
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "number": isinstance(value, (int, float)) and not isinstance(value, bool),
        "boolean": isinstance(value, bool),
    }.get(declared, False)


def _schema_error(label: str, message: str) -> None:
    raise ValidationError(f"{label}のschema違反: {message}")


def _validate_schema(value: Any, schema: dict[str, Any], label: str, path: str = "$") -> None:
    """このharnessのJSON Schema語彙を依存なしで厳密に照合する。"""
    declared = schema.get("type")
    if declared is not None:
        choices = declared if isinstance(declared, list) else [declared]
        if not any(_type_matches(value, item) for item in choices):
            _schema_error(label, f"{path}の型が不正")
    if "const" in schema and value != schema["const"]:
        _schema_error(label, f"{path}の値が不正")
    if "enum" in schema and value not in schema["enum"]:
        _schema_error(label, f"{path}の値が不正")
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            _schema_error(label, f"{path}が短すぎる")
        if "pattern" in schema and re.fullmatch(schema["pattern"], value) is None:
            _schema_error(label, f"{path}のpatternが不正")
    if isinstance(value, list):
        if schema.get("uniqueItems") and len({json.dumps(item, ensure_ascii=False, sort_keys=True) for item in value}) != len(value):
            _schema_error(label, f"{path}に重複がある")
        item_schema = schema.get("items")
        if item_schema:
            for index, item in enumerate(value):
                _validate_schema(item, item_schema, label, f"{path}[{index}]")
    if isinstance(value, dict):
        required = set(schema.get("required", []))
        _require(value, required, label)
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            unknown = set(value) - set(properties)
            if unknown:
                _schema_error(label, f"{path}に未知の項目がある: {', '.join(sorted(unknown))}")
        for key, item in value.items():
            if key in properties:
                _validate_schema(item, properties[key], label, f"{path}.{key}")


def _load_schema(name: str) -> dict[str, Any]:
    try:
        return json.loads((SCHEMAS / name).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"schemaを読めない: {name}") from exc


def validate_manifest(value: Any) -> dict[str, Any]:
    _validate_schema(value, _load_schema("run-manifest.schema.json"), "run manifest")
    if not isinstance(value, dict):  # schema検証後の型絞り込み
        raise ValidationError("run manifestはobjectが必要")
    required = {"version", "task_id", "role", "runtime", "repo_root", "plan_path", "program_path", "child_id", "base_commit", "worktree_path", "branch", "result_path", "evaluation_path", "phase"}
    _require(value, required, "run manifest")
    if value["version"] != 1 or not isinstance(value["task_id"], str) or not TASK_ID.fullmatch(value["task_id"]):
        raise ValidationError("run manifestのversionまたはtask_idが不正")
    if value["role"] not in ROLES or value["runtime"] not in RUNTIMES or value["phase"] not in PHASES:
        raise ValidationError("run manifestのrole/runtime/phaseが不正")
    for key in ("repo_root", "plan_path", "base_commit", "result_path"):
        if not isinstance(value[key], str) or not value[key]:
            raise ValidationError(f"run manifestの{key}が不正")
    for key in ("program_path", "child_id", "worktree_path", "branch", "evaluation_path"):
        if value[key] is not None and not isinstance(value[key], str):
            raise ValidationError(f"run manifestの{key}が不正")
    if "allowed_paths" in value and (not isinstance(value["allowed_paths"], list) or not all(isinstance(p, str) and p for p in value["allowed_paths"])):
        raise ValidationError("run manifestのallowed_pathsが不正")
    if value["role"] == "implementer" and (not value["worktree_path"] or not value["branch"]):
        raise ValidationError("write taskにはworktree_pathとbranchが必要")
    return value


def validate_result(value: Any) -> dict[str, Any]:
    _validate_schema(value, _load_schema("result-packet.schema.json"), "result packet")
    if not isinstance(value, dict):
        raise ValidationError("result packetはobjectが必要")
    required = {"version", "task_id", "status", "base_commit", "result_commit", "changed_paths", "tests", "assumptions", "blockers", "remaining_risks", "out_of_scope_findings"}
    _require(value, required, "result packet")
    if value["version"] != 1 or value["status"] not in STATUSES:
        raise ValidationError("result packetのversionまたはstatusが不正")
    if not isinstance(value["changed_paths"], list) or not isinstance(value["tests"], list):
        raise ValidationError("result packetのchanged_paths/testsは配列が必要")
    for path in value["changed_paths"]:
        if not isinstance(path, str) or Path(path).is_absolute() or path.startswith("../"):
            raise ValidationError("result packetのchanged_pathsはrepo相対pathが必要")
    for test in value["tests"]:
        if not isinstance(test, dict) or {"command", "status", "summary"} - set(test):
            raise ValidationError("result packetのtests要素が不正")
        if test["status"] not in {"passed", "failed", "skipped", "not_run"}:
            raise ValidationError("result packetのtests.statusが不正")
        if test["status"] == "passed" and (not test["command"].strip() or not test["summary"].strip()):
            raise ValidationError("未実行テストをpassedにできません")
    for key in ("assumptions", "blockers", "remaining_risks", "out_of_scope_findings"):
        if not isinstance(value[key], list):
            raise ValidationError(f"result packetの{key}は配列が必要")
    if _SECRET.search(json.dumps(value, ensure_ascii=False)):
        raise ValidationError("result packetにcredentialらしい値を含められません")
    return value


def read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"JSONを読めない: {path.name}: {exc}") from exc


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


_SECRET = re.compile(r"(?i)(?:sk-[a-z0-9_-]{8,}|(?:api[_-]?key|token|secret|password)\s*[=:]\s*)[^\s\"']+")


def redact(text: str) -> str:
    """Never persist typical credential-shaped process output verbatim."""
    return _SECRET.sub("[REDACTED]", text)
