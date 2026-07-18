#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: global-skill-registry/scripts/link-global-skill.sh [--dry-run] <skill-name>
       global-skill-registry/scripts/link-global-skill.sh [--dry-run] --all

Creates direct symlinks from runtime global Skill entries to:
  AIエージェント基盤/skills/<skill-name>

Exposure windows (既定=4窓すべて。Codexは ~/.agents/skills 経由で読むため
~/.codex/skills はこのscriptの露出対象に含めない。~/.codex/skills は設定専用):
  agents             -> ~/.agents/skills/<skill-name>                  # npx skills共通ハブ（opencode等 .skill-lock.json lastSelectedAgents をカバー。Codexもここを読む）
  claude             -> ~/.claude/skills/<skill-name>                  # Claude Code
  gemini-config      -> ~/.gemini/config/skills/<skill-name>           # Gemini CLI
  gemini-antigravity -> ~/.gemini/antigravity-cli/skills/<skill-name>  # Antigravity CLI

manifest（例外だけ列挙方式・第2の正本にしない）:
  scripts/exposure-manifest.tsv に `<skill><TAB><窓キーのカンマ区切り>` があれば、
  そのskillは記載された窓だけへ露出する。manifestに無いskillは既定4窓へ露出する。

Note: opencode has no dedicated skills dir (~/.config/opencode/skills); it is covered via ~/.agents/skills.
USAGE
}

dry_run=0
all_mode=0
skill=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --all)
      all_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 1
      ;;
    *)
      if [[ -n "$skill" || "$all_mode" == "1" ]]; then
        usage
        exit 1
      fi
      skill="$1"
      shift
      ;;
  esac
done

if [[ "$all_mode" == "1" && -n "$skill" ]]; then
  usage
  exit 1
fi

if [[ "$all_mode" != "1" && -z "$skill" ]]; then
  usage
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
manifest_file="$script_dir/exposure-manifest.tsv"

default_windows="agents,claude,gemini-config,gemini-antigravity"

# 窓キー -> runtime実パスの対応表（check-exposure.sh側にも同じ対応表がある。
# 別ファイルなので重複定義だが、共通化するほどの複雑さではないため許容）。
window_path_for_key() {
  case "$1" in
    agents) echo "$HOME/.agents/skills" ;;
    claude) echo "$HOME/.claude/skills" ;;
    gemini-config) echo "$HOME/.gemini/config/skills" ;;
    gemini-antigravity) echo "$HOME/.gemini/antigravity-cli/skills" ;;
    *)
      echo "Unknown exposure window key: $1" >&2
      exit 1
      ;;
  esac
}

# manifestから対象skillの窓キーCSVを取る。無ければ空文字を返す（呼び出し側で既定にfallback）。
manifest_windows_for_skill() {
  local target_skill="$1"
  [[ -f "$manifest_file" ]] || return 0
  awk -F'\t' -v s="$target_skill" '
    $0 ~ /^#/ { next }
    NF < 2 { next }
    $1 == s { print $2; exit }
  ' "$manifest_file"
}

validate_skill_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Invalid skill name: $name" >&2
    echo "Use lowercase kebab-case: letters, digits, hyphens; no slash, dot, space, leading/trailing hyphen." >&2
    exit 1
  fi
}

verify_link() {
  local link="$1"
  local expected_source="$2"
  local target
  target="$(readlink "$link" 2>/dev/null || true)"

  # inode等価テスト（-ef）で正本を指すか判定。生文字列比較はUnicode正規化差
  # （NFC/NFD）で日本語パスを誤検出するため使わない。-efはsymlinkを追って実体の
  # device/inodeを比較するので、正本を指す健全リンクなら正規化差に依存せずtrue。
  if [[ ! "$link" -ef "$expected_source" ]]; then
    echo "Link verification failed: $link -> $target, expected $expected_source" >&2
    exit 1
  fi

  if [[ ! -r "$link/SKILL.md" ]]; then
    echo "SKILL.md is not readable through runtime link: $link/SKILL.md" >&2
    exit 1
  fi
}

link_skill() {
  local target_skill="$1"

  validate_skill_name "$target_skill"

  local source_dir="$repo_root/skills/$target_skill"

  if [[ ! -d "$source_dir" ]]; then
    echo "Missing canonical Skill directory: $source_dir" >&2
    exit 1
  fi

  if [[ ! -f "$source_dir/SKILL.md" ]]; then
    echo "Missing SKILL.md: $source_dir/SKILL.md" >&2
    exit 1
  fi

  local windows_csv
  windows_csv="$(manifest_windows_for_skill "$target_skill")"
  if [[ -z "$windows_csv" ]]; then
    windows_csv="$default_windows"
  fi

  local old_ifs="$IFS"
  IFS=','
  local window_keys=($windows_csv)
  IFS="$old_ifs"

  local key root link current_target
  for key in "${window_keys[@]}"; do
    root="$(window_path_for_key "$key")"
    link="$root/$target_skill"

    if [[ -e "$link" && ! -L "$link" ]]; then
      echo "Refusing to replace non-symlink path: $link" >&2
      exit 1
    fi

    current_target=""
    if [[ -L "$link" ]]; then
      current_target="$(readlink "$link")"
    fi

    # inode等価テスト（-ef）で既にリンク済みか判定（正規化差に非依存）。
    # -efはsymlinkを追うため、broken link（実体が解決できない）はfalseになり、
    # 下の再作成フローで正しく張り直される。
    if [[ -L "$link" && "$link" -ef "$source_dir" ]]; then
      verify_link "$link" "$source_dir"
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
    verify_link "$link" "$source_dir"
    echo "$link -> $(readlink "$link")"
  done
}

if [[ "$all_mode" == "1" ]]; then
  skills_root="$repo_root/skills"
  if [[ ! -d "$skills_root" ]]; then
    echo "Missing canonical skills root: $skills_root" >&2
    exit 1
  fi
  shopt -s nullglob
  for entry in "$skills_root"/*/; do
    entry_name="$(basename "$entry")"
    if [[ ! -f "$entry/SKILL.md" ]]; then
      continue
    fi
    link_skill "$entry_name"
  done
  shopt -u nullglob
else
  link_skill "$skill"
fi
