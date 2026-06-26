#!/usr/bin/env bash
set -u

ROOT_FILE="docs/agent/root-agent-router.md"
START_MARK="<!-- AGENT-ROUTER:START -->"
END_MARK="<!-- AGENT-ROUTER:END -->"
TARGETS=("CLAUDE.md" "AGENTS.md")

status=0

if [ ! -f "$ROOT_FILE" ]; then
  echo "ERROR: missing $ROOT_FILE" >&2
  exit 1
fi

sync_one() {
  local target="$1"
  local before after block

  if [ ! -f "$target" ]; then
    echo "ERROR: missing $target" >&2
    status=1
    return
  fi

  before="$(mktemp)"
  after="$(mktemp)"
  block="$(mktemp)"
  cp "$target" "$before"

  {
    echo "$START_MARK"
    cat "$ROOT_FILE"
    echo "$END_MARK"
  } > "$block"

  if grep -qF "$START_MARK" "$target" && grep -qF "$END_MARK" "$target"; then
    awk -v start="$START_MARK" -v end="$END_MARK" -v block="$block" '
      BEGIN {
        while ((getline line < block) > 0) replacement = replacement line "\n"
        close(block)
        in_block = 0
      }
      index($0, start) {
        printf "%s", replacement
        in_block = 1
        next
      }
      index($0, end) {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$target" > "$after"
  else
    awk -v block="$block" '
      BEGIN {
        while ((getline line < block) > 0) replacement = replacement line "\n"
        close(block)
        inserted = 0
      }
      NR == 1 {
        print
        printf "\n%s\n", replacement
        inserted = 1
        next
      }
      { print }
      END {
        if (!inserted) printf "%s\n", replacement
      }
    ' "$target" > "$after"
  fi

  if cmp -s "$before" "$after"; then
    echo "OK: $target already synchronized"
  else
    echo "UPDATED: $target"
    diff -u "$before" "$after" || true
    mv "$after" "$target"
  fi

  rm -f "$before" "$after" "$block"
}

for target in "${TARGETS[@]}"; do
  sync_one "$target"
done

exit "$status"
