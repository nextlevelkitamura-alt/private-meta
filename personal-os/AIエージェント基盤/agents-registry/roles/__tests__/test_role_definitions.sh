#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$(cd "$ROOT/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for role in explorer implementer reviewer; do
  role_file="$ROOT/$role.md"
  claude_file="$REGISTRY/claude/agents/$role.md"
  codex_file="$REGISTRY/codex/agents/$role.toml"

  test -f "$role_file" || fail "役割正本がない: $role"
  test -f "$claude_file" || fail "Claude写像がない: $role"
  test -f "$codex_file" || fail "Codex写像がない: $role"
  grep -Fq "agents-registry/roles/$role.md" "$claude_file" || fail "Claude写像が正本を参照しない: $role"
  grep -Fq "agents-registry/roles/$role.md" "$codex_file" || fail "Codex写像が正本を参照しない: $role"
  grep -Eq '^name = "'"$role"'"$' "$codex_file" || fail "Codex nameが不正: $role"
  grep -Eq '^description = "' "$codex_file" || fail "Codex descriptionがない: $role"
  grep -Eq '^developer_instructions = """$' "$codex_file" || fail "Codex developer_instructionsがない: $role"
  test "$(grep -c '^性格:' "$role_file")" -eq 1 || fail "性格は1行だけにする: $role"
  awk '/^性格:/ && length($0) > 80 { exit 1 }' "$role_file" || fail "性格が長すぎる: $role"
done

grep -Eq '^sandbox_mode = "read-only"$' "$REGISTRY/codex/agents/explorer.toml" || fail "explorerはread-onlyではない"
grep -Eq '^sandbox_mode = "workspace-write"$' "$REGISTRY/codex/agents/implementer.toml" || fail "implementerはworkspace-writeではない"
grep -Eq '^sandbox_mode = "read-only"$' "$REGISTRY/codex/agents/reviewer.toml" || fail "reviewerはread-onlyではない"

if rg -n -i --glob '*.md' \
  '(固定(worktree|branch)|固定モデル|model[_ -]?id|gpt-[0-9]|claude-[0-9]|program固有|task[_ -]?id:|worktree_path:|branch:)' \
  "$ROOT"; then
  fail '役割正本に実行時の固定値または長い固有背景がある'
fi

printf 'PASS: rolesの正本・薄い写像・禁止事項を確認\n'
