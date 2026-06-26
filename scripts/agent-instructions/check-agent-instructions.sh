#!/usr/bin/env bash
set -u

ROOT_FILE="docs/agent/root-agent-router.md"
START_MARK="<!-- AGENT-ROUTER:START -->"
END_MARK="<!-- AGENT-ROUTER:END -->"
TARGETS=("CLAUDE.md" "AGENTS.md")
REQUIRED_PATHS=(
  "docs/agent/root-agent-router.md"
  "docs/agent/claude-specific-notes.md"
  "docs/agent/codex-specific-notes.md"
  "docs/agent/agent-file-policy.md"
  "docs/agent/compatibility-checklist.md"
  "docs/requirements/README.md"
  "docs/requirements/product-requirements.md"
  "docs/requirements/requirements-ledger.md"
  "docs/requirements/progress-board.md"
  "docs/requirements/contradictions.md"
  "docs/requirements/non-goals.md"
  "docs/requirements/change-log.md"
  "docs/requirements/glossary.md"
  "docs/specs/README.md"
  "docs/adr/README.md"
)

status=0

fail() {
  echo "ERROR: $*" >&2
  status=1
}

warn() {
  echo "WARN: $*" >&2
}

extract_router() {
  local file="$1"
  awk -v start="$START_MARK" -v end="$END_MARK" '
    index($0, start) { in_block = 1; next }
    index($0, end) { in_block = 0; next }
    in_block { print }
  ' "$file"
}

echo "== Entry file existence and line counts =="
for file in "${TARGETS[@]}"; do
  if [ ! -f "$file" ]; then
    fail "missing $file"
    continue
  fi

  lines="$(wc -l < "$file" | tr -d " ")"
  echo "$file: $lines lines"
  if [ "$lines" -gt 300 ]; then
    fail "$file exceeds 300 lines"
  elif [ "$lines" -gt 250 ]; then
    warn "$file exceeds 250 lines"
  fi

  if ! grep -qF "$START_MARK" "$file"; then
    fail "$file missing router start marker"
  fi
  if ! grep -qF "$END_MARK" "$file"; then
    fail "$file missing router end marker"
  fi
done

echo
echo "== Router block comparison =="
if [ ! -f "$ROOT_FILE" ]; then
  fail "missing $ROOT_FILE"
else
  for file in "${TARGETS[@]}"; do
    [ -f "$file" ] || continue
    tmp="$(mktemp)"
    extract_router "$file" > "$tmp"
    if diff -u "$ROOT_FILE" "$tmp" >/dev/null; then
      echo "OK: $file router matches $ROOT_FILE"
    else
      fail "$file router does not match $ROOT_FILE"
      diff -u "$ROOT_FILE" "$tmp" || true
    fi
    rm -f "$tmp"
  done
fi

echo
echo "== Required reference paths =="
for path in "${REQUIRED_PATHS[@]}"; do
  if [ -e "$path" ]; then
    echo "OK: $path"
  else
    fail "missing $path"
  fi
done

if [ "$status" -eq 0 ]; then
  echo
  echo "PASS: agent instruction files are synchronized"
else
  echo
  echo "FAIL: agent instruction files need attention" >&2
fi

exit "$status"
