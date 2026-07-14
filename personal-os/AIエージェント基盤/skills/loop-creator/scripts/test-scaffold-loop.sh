#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scaffold="$script_dir/scaffold-loop.sh"
verify_link="$script_dir/verify-repo-loop-link.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/loop-creator-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

root="$tmp/repo/loops"
mkdir -p "$root"
root="$(cd "$root" && pwd -P)"
printf '# fixture contract\n' > "$root/AGENTS.md"

dry_output="$($scaffold --root "$root" --id morning-check --owner fixture --scope repo-local --runner script)"
[[ "$dry_output" == *"would create only"* ]]
[[ ! -e "$root/morning-check" ]]

$scaffold --root "$root" --id morning-check --owner fixture --scope repo-local --runner script --apply >/dev/null
[[ -f "$root/morning-check/loop.md" ]]
[[ "$(find "$root/morning-check" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == "1" ]]
rg -q '^## 発火$' "$root/morning-check/loop.md"
rg -q '意図状態: 未稼働' "$root/morning-check/loop.md"

idempotent_output="$($scaffold --root "$root" --id morning-check --owner fixture --scope repo-local --runner script --apply)"
[[ "$idempotent_output" == *"Already scaffolded with matching"* ]]

if $scaffold --root "$root" --id morning-check --owner other --scope repo-local --runner script --apply >/dev/null 2>&1; then
  echo "Expected conflicting metadata refusal" >&2
  exit 1
fi

if $scaffold --root "$root" --id 'Bad/Id' --owner fixture --scope repo-local --runner script >/dev/null 2>&1; then
  echo "Expected invalid-id refusal" >&2
  exit 1
fi

missing_contract="$tmp/no-contract/loops"
mkdir -p "$missing_contract"
missing_contract="$(cd "$missing_contract" && pwd -P)"
if $scaffold --root "$missing_contract" --id no-contract --owner fixture --scope repo-local --runner script >/dev/null 2>&1; then
  echo "Expected missing-contract refusal" >&2
  exit 1
fi

ancestor_contract="$tmp/ancestor-contract/repo/loops"
mkdir -p "$ancestor_contract"
printf '# unrelated parent contract\n' > "$tmp/ancestor-contract/repo/AGENTS.md"
ancestor_contract="$(cd "$ancestor_contract" && pwd -P)"
if $scaffold --root "$ancestor_contract" --id undeclared-root --owner fixture --scope repo-local --runner script >/dev/null 2>&1; then
  echo "Expected root-local contract refusal" >&2
  exit 1
fi

mkdir -p "$tmp/alias"
ln -s "$root" "$tmp/alias/loops"
if $scaffold --root "$tmp/alias/loops" --id symlink-root --owner fixture --scope repo-local --runner script >/dev/null 2>&1; then
  echo "Expected symlink-root refusal" >&2
  exit 1
fi

link_dir="$tmp/foundation/implementation-links"
mkdir -p "$link_dir" "$tmp/repo/wrong"
ln -s ../../repo/loops "$link_dir/fixture"
$verify_link --link "$link_dir/fixture" --root "$root" >/dev/null

ln -s ../../repo/wrong "$link_dir/mismatch"
if $verify_link --link "$link_dir/mismatch" --root "$root" >/dev/null 2>&1; then
  echo "Expected mismatched implementation link refusal" >&2
  exit 1
fi

echo "PASS: scaffold and implementation link checks fail closed"
