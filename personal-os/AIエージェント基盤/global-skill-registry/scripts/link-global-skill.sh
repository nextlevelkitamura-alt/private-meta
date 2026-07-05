#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: global-skill-registry/scripts/link-global-skill.sh [--dry-run] <skill-name>

Creates direct symlinks from runtime global Skill entries to:
  AIエージェント基盤/skills/<skill-name>

Targets:
  ~/.agents/skills/<skill-name>
  ~/.codex/skills/<skill-name>
  ~/.claude/skills/<skill-name>
  ~/.gemini/config/skills/<skill-name>
  ~/.gemini/antigravity-cli/skills/<skill-name>
USAGE
}

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

skill="${1:-}"
if [[ -z "$skill" || "$skill" == "-h" || "$skill" == "--help" ]]; then
  usage
  exit 1
fi

if [[ ! "$skill" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "Invalid skill name: $skill" >&2
  echo "Use lowercase kebab-case: letters, digits, hyphens; no slash, dot, space, leading/trailing hyphen." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source_dir="$repo_root/skills/$skill"

if [[ ! -d "$source_dir" ]]; then
  echo "Missing canonical Skill directory: $source_dir" >&2
  exit 1
fi

if [[ ! -f "$source_dir/SKILL.md" ]]; then
  echo "Missing SKILL.md: $source_dir/SKILL.md" >&2
  exit 1
fi

roots=(
  "$HOME/.agents/skills"
  "$HOME/.codex/skills"
  "$HOME/.claude/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.gemini/antigravity-cli/skills"
)

verify_link() {
  local link="$1"
  local target
  target="$(readlink "$link" 2>/dev/null || true)"

  if [[ "$target" != "$source_dir" ]]; then
    echo "Link verification failed: $link -> $target, expected $source_dir" >&2
    exit 1
  fi

  if [[ ! -r "$link/SKILL.md" ]]; then
    echo "SKILL.md is not readable through runtime link: $link/SKILL.md" >&2
    exit 1
  fi
}

for root in "${roots[@]}"; do
  link="$root/$skill"

  if [[ -e "$link" && ! -L "$link" ]]; then
    echo "Refusing to replace non-symlink path: $link" >&2
    exit 1
  fi

  current_target=""
  if [[ -L "$link" ]]; then
    current_target="$(readlink "$link")"
  fi

  if [[ "$current_target" == "$source_dir" ]]; then
    verify_link "$link"
    echo "Already linked: $link -> $current_target"
    continue
  fi

  if [[ "$dry_run" == "1" ]]; then
    if [[ ! -d "$root" ]]; then
      echo "Would create directory: $root"
    fi
    if [[ -L "$link" ]]; then
      echo "Would replace symlink: $link -> $current_target"
    else
      echo "Would create symlink: $link"
    fi
    echo "  target: $source_dir"
    continue
  fi

  mkdir -p "$root"

  if [[ -L "$link" ]]; then
    rm "$link"
  fi

  ln -s "$source_dir" "$link"
  verify_link "$link"
  echo "$link -> $(readlink "$link")"
done
