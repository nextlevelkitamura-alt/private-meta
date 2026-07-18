#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: global-skill-registry/scripts/check-exposure.sh

Read-only drift check for Global Skill runtime exposure. Does not modify
anything (no symlink creation/removal). Exits non-zero if drift is found.

Checks per canonical Skill under AIエージェント基盤/skills/:
  1. Exposure windows (manifest分の窓、無ければ既定4窓すべて) について、
     symlinkが正本skills/<skill>を指して存在するか（欠落・非symlink・broken link・
     symlink先不一致を検出）。
  2. manifestで許可されていない窓へ露出していないか（余計な露出を警告）。
  3. ~/.codex/skills/<skill> が正本skills/<skill>を指すsymlinkとして存在する場合、
     「Codex二重登録」として警告する（Codexは~/.agents/skills経由が既定のため、移行後は0件が正）。

Global check (once, not per skill):
  4. ~/.codex/skills/ 配下にsymlinkでない実ディレクトリ（Codex自動生成skillなど）が
     あれば「要確認(scratch)」として一覧表示する（エラーにはしない）。

Exposure windows and manifest format mirror scripts/link-global-skill.sh and
scripts/exposure-manifest.tsv.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
manifest_file="$script_dir/exposure-manifest.tsv"
skills_root="$repo_root/skills"
codex_skills_root="$HOME/.codex/skills"

default_windows="agents,claude,gemini-config,gemini-antigravity"
all_window_keys=(agents claude gemini-config gemini-antigravity)

# 窓キー -> runtime実パスの対応表（link-global-skill.shと同一。別ファイルのため
# コピー定義だが、read-only checkであり複雑な共通化はしない）。
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

manifest_windows_for_skill() {
  local target_skill="$1"
  [[ -f "$manifest_file" ]] || return 0
  awk -F'\t' -v s="$target_skill" '
    $0 ~ /^#/ { next }
    NF < 2 { next }
    $1 == s { print $2; exit }
  ' "$manifest_file"
}

csv_contains() {
  local csv="$1" needle="$2"
  local old_ifs="$IFS"
  IFS=','
  local items=($csv)
  IFS="$old_ifs"
  local item
  for item in "${items[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

drift_count=0
note() {
  echo "  - $1"
}
flag_drift() {
  note "$1"
  drift_count=$((drift_count + 1))
}

if [[ ! -d "$skills_root" ]]; then
  echo "Missing canonical skills root: $skills_root" >&2
  exit 1
fi

shopt -s nullglob
skill_dirs=("$skills_root"/*/)
shopt -u nullglob

if [[ "${#skill_dirs[@]}" -eq 0 ]]; then
  echo "No canonical skills found under: $skills_root"
fi

for entry in "${skill_dirs[@]}"; do
  skill="$(basename "$entry")"
  [[ -f "$entry/SKILL.md" ]] || continue
  source_dir="$repo_root/skills/$skill"

  windows_csv="$(manifest_windows_for_skill "$skill")"
  if [[ -z "$windows_csv" ]]; then
    windows_csv="$default_windows"
  fi

  echo "## $skill (expected windows: $windows_csv)"

  for key in "${all_window_keys[@]}"; do
    root="$(window_path_for_key "$key")"
    link="$root/$skill"
    expected=0
    if csv_contains "$windows_csv" "$key"; then
      expected=1
    fi

    if [[ "$expected" == "1" ]]; then
      if [[ ! -e "$link" && ! -L "$link" ]]; then
        flag_drift "欠落: $link (window=$key) が存在しない"
        continue
      fi
      if [[ ! -L "$link" ]]; then
        flag_drift "非symlink: $link (window=$key) はsymlinkではない実体"
        continue
      fi
      link_target="$(readlink "$link")"
      if [[ ! -e "$link" ]]; then
        flag_drift "broken link: $link (window=$key) -> $link_target が解決できない"
        continue
      fi
      # inode等価テスト（-ef）で判定。生文字列比較はUnicode正規化差（NFC/NFD）で
      # 日本語パスを誤検出するため使わない。ここは既にbroken link判定を通過済み。
      if [[ ! "$link" -ef "$source_dir" ]]; then
        flag_drift "symlink先不一致: $link (window=$key) -> $link_target, expected $source_dir"
        continue
      fi
      note "OK: $link (window=$key)"
    else
      if [[ -L "$link" ]]; then
        # inode等価テスト（-ef）で正本を指すか判定（正規化差に非依存）。
        if [[ "$link" -ef "$source_dir" ]]; then
          flag_drift "余計な露出: $link (window=$key) はmanifestで許可されていないが正本へ露出している"
        fi
      fi
    fi
  done

  # Codex二重登録チェック（~/.agents/skills経由が既定・~/.codex/skillsは設定専用）
  codex_link="$codex_skills_root/$skill"
  if [[ -L "$codex_link" ]]; then
    codex_target="$(readlink "$codex_link")"
    # inode等価テスト（-ef）で正本を指すか判定（正規化差に非依存）。
    if [[ "$codex_link" -ef "$source_dir" ]]; then
      flag_drift "Codex二重登録: $codex_link -> $codex_target（~/.codex/skills は既定露出先から除外済み・削除検討）"
    fi
  fi
done

echo ""
echo "## ~/.codex/skills scratch check (informational, not drift)"
if [[ -d "$codex_skills_root" ]]; then
  shopt -s nullglob
  codex_entries=("$codex_skills_root"/*/)
  shopt -u nullglob
  scratch_found=0
  for codex_entry in "${codex_entries[@]}"; do
    codex_name="$(basename "$codex_entry")"
    codex_path="$codex_skills_root/$codex_name"
    if [[ ! -L "$codex_path" && -d "$codex_path" ]]; then
      echo "  - 要確認(scratch): $codex_path（symlinkでない実ディレクトリ・Codex自動生成の可能性）"
      scratch_found=1
    fi
  done
  if [[ "$scratch_found" == "0" ]]; then
    echo "  (none)"
  fi
else
  echo "  (no ~/.codex/skills directory)"
fi

echo ""
if [[ "$drift_count" -gt 0 ]]; then
  echo "Drift detected: $drift_count issue(s)."
  exit 1
fi

echo "No drift detected."
exit 0
