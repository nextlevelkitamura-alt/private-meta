#!/usr/bin/env bash
set -u

CLAUDE_SKILL=".claude/skills/requirements-governor"
AGENTS_SKILL=".agents/skills/requirements-governor"
SKILL_FILE="SKILL.md"
COMPAT_FILE="docs/agent/compatibility-checklist.md"
START_MARK="<!-- COMPATIBILITY-TEST:START -->"
END_MARK="<!-- COMPATIBILITY-TEST:END -->"
REFERENCES=(
  "audit-mode.md"
  "feature-gate-mode.md"
  "progress-sync-mode.md"
  "contradiction-review-mode.md"
  "templates.md"
  "status-rules.md"
  "done-definition.md"
)

status=0
RESULT_LINES=()

add_result() {
  RESULT_LINES+=("$*")
  echo "$*"
}

fail() {
  add_result "ERROR: $*"
  status=1
}

check_skill_file() {
  local skill_dir="$1"
  local label="$2"
  local file="$skill_dir/$SKILL_FILE"

  if [ ! -e "$file" ]; then
    fail "$label missing $file"
    return
  fi

  add_result "OK: $label skill file resolves at $file"

  if grep -q '^name: requirements-governor$' "$file"; then
    add_result "OK: $label frontmatter name"
  else
    fail "$label frontmatter missing name: requirements-governor"
  fi

  if grep -q '^description: .*requirements' "$file"; then
    add_result "OK: $label frontmatter description"
  else
    fail "$label frontmatter missing description"
  fi
}

update_compat_file() {
  [ -f "$COMPAT_FILE" ] || return

  local tmp body
  tmp="$(mktemp)"
  body="$(mktemp)"

  {
    echo "Last run: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo
    for line in "${RESULT_LINES[@]}"; do
      echo "- $line"
    done
  } > "$body"

  if grep -qF "$START_MARK" "$COMPAT_FILE" && grep -qF "$END_MARK" "$COMPAT_FILE"; then
    awk -v start="$START_MARK" -v end="$END_MARK" -v body="$body" '
      BEGIN {
        while ((getline line < body) > 0) replacement = replacement line "\n"
        close(body)
        in_block = 0
      }
      index($0, start) {
        print
        printf "%s", replacement
        in_block = 1
        next
      }
      index($0, end) {
        in_block = 0
        print
        next
      }
      !in_block { print }
    ' "$COMPAT_FILE" > "$tmp"
    mv "$tmp" "$COMPAT_FILE"
  else
    {
      cat "$COMPAT_FILE"
      echo
      echo "$START_MARK"
      cat "$body"
      echo "$END_MARK"
    } > "$tmp"
    mv "$tmp" "$COMPAT_FILE"
  fi

  rm -f "$body"
}

echo "== Skill path checks =="
if [ -d "$CLAUDE_SKILL" ]; then
  add_result "OK: Claude skill directory exists"
else
  fail "Claude skill directory missing: $CLAUDE_SKILL"
fi

if [ -L "$AGENTS_SKILL" ]; then
  target="$(readlink "$AGENTS_SKILL")"
  add_result "OK: Codex skill directory is symlink -> $target"
  if [ -e "$AGENTS_SKILL/$SKILL_FILE" ]; then
    add_result "OK: Codex symlink target resolves"
  else
    fail "Codex symlink target is broken"
  fi
elif [ -d "$AGENTS_SKILL" ]; then
  add_result "OK: Codex skill directory exists as copy"
  if diff -qr "$CLAUDE_SKILL" "$AGENTS_SKILL" >/dev/null; then
    add_result "OK: Claude and Codex skill copies match"
  else
    fail "Claude and Codex skill copies differ"
    diff -qr "$CLAUDE_SKILL" "$AGENTS_SKILL" || true
  fi
else
  fail "Codex skill directory missing: $AGENTS_SKILL"
fi

echo
echo "== Skill frontmatter checks =="
check_skill_file "$CLAUDE_SKILL" "Claude"
check_skill_file "$AGENTS_SKILL" "Codex"

echo
echo "== Reference file checks =="
for ref in "${REFERENCES[@]}"; do
  if [ -e "$CLAUDE_SKILL/references/$ref" ]; then
    add_result "OK: reference exists $ref"
  else
    fail "missing reference $ref"
  fi
done

echo
echo "== CLI availability =="
if command -v claude >/dev/null 2>&1; then
  claude_path="$(command -v claude)"
  add_result "OK: claude CLI found at $claude_path"
  if claude --help >/dev/null 2>&1; then
    add_result "OK: claude --help completed"
  else
    add_result "WARN: claude --help did not complete successfully; no further CLI test run"
  fi
else
  add_result "INFO: claude CLI not found; manual Claude Code skill detection remains unverified"
fi

if command -v codex >/dev/null 2>&1; then
  codex_path="$(command -v codex)"
  add_result "OK: codex CLI found at $codex_path"
  if codex --help >/dev/null 2>&1; then
    add_result "OK: codex --help completed"
  else
    add_result "WARN: codex --help did not complete successfully; no further CLI test run"
  fi
else
  add_result "INFO: codex CLI not found; manual Codex skill detection remains unverified"
fi

update_compat_file

if [ "$status" -eq 0 ]; then
  echo
  echo "PASS: requirements-governor skill compatibility checks passed"
else
  echo
  echo "FAIL: requirements-governor skill compatibility checks need attention" >&2
fi

exit "$status"
