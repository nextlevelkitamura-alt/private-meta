#!/usr/bin/env bash
set -euo pipefail

# 用途: 評価01 R11 の rollback素材。
# 本programで撤去した ~/.codex/skills 配下のCodexミラーsymlinkを一括復元する。
# 変更前snapshot（2026-07-18-snapshot-symlinks.txt）の `== .../.codex/skills ==` 節から、
# 正本 AIエージェント基盤/skills/ を指すエントリだけを読み、
# `ln -s <target> ~/.codex/skills/<name>` を再作成する。
# 起業スキル/skills/ を指すエントリ（ai-news-short-video 等）は正本外なので除外する。
#
# 既定は --dry-run（表示のみ・実HOMEは変更しない）。
# 実際にsymlinkを作成するのは --apply を明示したときだけ。
#
# Usage:
#   bash rollback-codex-skills.sh            # dry-run（既定・表示のみ）
#   bash rollback-codex-skills.sh --dry-run  # 同上
#   bash rollback-codex-skills.sh --apply    # 実際にsymlinkを作成

mode="dry-run"
case "${1:-}" in
  --apply)   mode="apply" ;;
  --dry-run|"") mode="dry-run" ;;
  -h|--help)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Use --dry-run (default) or --apply." >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
snapshot="$script_dir/2026-07-18-snapshot-symlinks.txt"
canonical_marker="AIエージェント基盤/skills/"
codex_root="$HOME/.codex/skills"

if [[ ! -f "$snapshot" ]]; then
  echo "Missing snapshot file: $snapshot" >&2
  exit 1
fi

# snapshotの `== .../.codex/skills ==` 節だけを抜き出し、
# `<name> -> <target>` を1行ずつ処理する。
in_section=0
count=0
missing_target=0

while IFS= read -r line; do
  # 節ヘッダ判定
  if [[ "$line" == "== "*" ==" ]]; then
    if [[ "$line" == *"/.codex/skills =="* ]]; then
      in_section=1
    else
      in_section=0
    fi
    continue
  fi
  [[ "$in_section" == "1" ]] || continue
  [[ -n "$line" ]] || continue
  [[ "$line" == "#"* ]] && continue

  # `name -> target` を分解
  name="${line%% -> *}"
  target="${line#* -> }"
  # 末尾スラッシュを正規化（note-create/ などの表記ゆれ対策）
  target="${target%/}"

  # 正本 AIエージェント基盤/skills/ を指すものだけ復元対象
  [[ "$target" == *"$canonical_marker"* ]] || continue

  count=$((count + 1))
  link="$codex_root/$name"

  if [[ ! -e "$target" ]]; then
    echo "WARN: target not found (実在しない): $target" >&2
    missing_target=$((missing_target + 1))
  fi

  if [[ "$mode" == "dry-run" ]]; then
    echo "ln -s $target $link"
  else
    mkdir -p "$codex_root"
    if [[ -e "$link" || -L "$link" ]]; then
      echo "SKIP (already exists): $link" >&2
      continue
    fi
    ln -s "$target" "$link"
    echo "created: $link -> $target"
  fi
done < "$snapshot"

echo ""
echo "対象: $count 件（正本 $canonical_marker を指す .codex/skills エントリ）"
if [[ "$missing_target" -gt 0 ]]; then
  echo "警告: target実在しない $missing_target 件（要確認）" >&2
fi
if [[ "$mode" == "dry-run" ]]; then
  echo "mode=dry-run（表示のみ・実HOMEは未変更）。実行するには --apply を付ける。"
else
  echo "mode=apply（symlinkを作成した）。"
fi
