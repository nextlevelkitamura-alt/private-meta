#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scaffold-loop.sh --root <absolute loops root> --id <loop-id> --owner <repo-id> --scope <global|repo-local> --runner <script|ai> [--apply]

Default is dry-run. --apply creates only <root>/<loop-id>/loop.md.
A repo-local root must have its own AGENTS.md. A global root must be the
canonical loops-registry/loops path.
USAGE
  exit 2
}

root=""
loop_id=""
owner=""
scope=""
runner=""
apply=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    --id) loop_id="${2:-}"; shift 2 ;;
    --owner) owner="${2:-}"; shift 2 ;;
    --scope) scope="${2:-}"; shift 2 ;;
    --runner) runner="${2:-}"; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -n "$root" && -n "$loop_id" && -n "$owner" && -n "$scope" && -n "$runner" ]] || usage
[[ "$root" == /* ]] || { echo "--root must be absolute: $root" >&2; exit 2; }
[[ -d "$root" ]] || { echo "Declared loops root does not exist: $root" >&2; exit 3; }
[[ "$(basename "$root")" == "loops" ]] || { echo "Root basename must be loops: $root" >&2; exit 3; }
[[ ! -L "$root" ]] || { echo "Refusing symlink root; use the canonical loops directory: $root" >&2; exit 3; }
[[ "$loop_id" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || { echo "Invalid loop id: $loop_id" >&2; exit 2; }
[[ "$scope" == "global" || "$scope" == "repo-local" ]] || { echo "Invalid scope: $scope" >&2; exit 2; }
[[ "$runner" == "script" || "$runner" == "ai" ]] || { echo "Invalid runner: $runner" >&2; exit 2; }
[[ "$owner" != */* && "$owner" != *$'\n'* ]] || { echo "Invalid owner: $owner" >&2; exit 2; }

logical_root="$(cd "$root" && pwd -L)"
physical_root="$(cd "$root" && pwd -P)"
[[ "$logical_root" == "$physical_root" ]] || {
  echo "Root resolves through a symlink; use canonical path: $logical_root -> $physical_root" >&2
  exit 3
}

global_root="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops"
if [[ "$scope" == "global" ]]; then
  [[ "$physical_root" == "$global_root" ]] || {
    echo "Global scope must use canonical root: $global_root" >&2
    exit 3
  }
  contract="$(dirname "$physical_root")/AGENTS.md"
  [[ -f "$contract" ]] || { echo "Missing global loops-registry contract: $contract" >&2; exit 3; }
else
  contract="$physical_root/AGENTS.md"
  [[ -f "$contract" ]] || { echo "Repo-local root needs its own AGENTS.md: $contract" >&2; exit 3; }
fi

target="$physical_root/$loop_id"
if [[ -e "$target" || -L "$target" ]]; then
  if [[ -f "$target/loop.md" ]] \
    && rg -Fqx -- "- 所有: \`$owner\`" "$target/loop.md" \
    && rg -Fqx -- "- scope: \`$scope\`" "$target/loop.md" \
    && rg -Fqx -- "- runner: \`$runner\`" "$target/loop.md"; then
    echo "Already scaffolded with matching owner, scope, and runner: $target/loop.md"
    exit 0
  fi
  echo "Refusing existing loop path with different or incomplete metadata: $target" >&2
  exit 4
fi

if [[ "$apply" == "0" ]]; then
  echo "Dry-run: would create only $target/loop.md"
  echo "Contract: $contract"
  echo "No scripts/, logs/, tests/, state/, output/, or plist will be created."
  exit 0
fi

mkdir "$target"
tmp="$target/.loop.md.tmp"
cleanup_on_error() {
  rm -f "$tmp"
  rmdir "$target" 2>/dev/null || true
}
trap cleanup_on_error ERR

{
  printf '# %s\n\n' "$loop_id"
  printf -- '- 所有: `%s`\n' "$owner"
  printf -- '- scope: `%s`\n' "$scope"
  printf -- '- runner: `%s`\n' "$runner"
  printf -- '- 意図状態: 未稼働（設定・検証完了まで有効化しない）\n\n'
  printf '## 目的\n\n<未設定: このloopが繰り返す責務>\n\n'
  printf '## 発火\n\n- 種別: <未設定: 時刻または間隔>\n- 設定: <未設定>\n- タイムゾーン: `Asia/Tokyo`\n\n'
  printf '## 実行\n\n- command: <未設定>\n- canonical path: `%s`\n- launchd label: <launchd利用時だけ。利用しないなら「なし」>\n\n' "$target"
  printf '## state・lock・logs・成果物\n\n- lock: <必要なら `/tmp`。不要なら「なし」>\n- 永続state: <既存正本・DB・不要のいずれか>\n- logs: <必要ならgitignoreされた `logs/`。不要なら「なし」>\n- 成果物: <既存正本・DB・dashboard・なしのいずれか>\n\n'
  printf '## 停止・復旧\n\n- 停止方法: <未設定>\n- rollback: <未設定>\n'
} > "$tmp"

mv "$tmp" "$target/loop.md"
trap - ERR
echo "Created: $target/loop.md"
echo "Next: replace every <未設定...> placeholder before validation or launchd registration."
