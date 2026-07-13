#!/usr/bin/env bash
# plan-ops / bucketctl — planning 配下の計画を active へ安全に昇格する。
# 既定は dry-run。active は実行中だけ・最大3件を保ち、追い出しや削除は一切しない。
set -euo pipefail

LIMIT=3

usage() {
  cat >&2 <<'EOF'
usage: bucketctl.sh promote <plans/planning/計画フォルダ> --to active [--apply|--commit]
  promote       planning 配下の計画フォルダを同じ plans/active/ へ git mv する。
  --to active   現在サポートする昇格先。省略・他の値はエラー。
  --apply       git mv だけを適用する。既定は dry-run。
  --commit      git mv を適用し、この移動だけを定型コミットする。

active が3件以上なら昇格を拒否し、現在の active 一覧を表示する。
何を paused/archive に移すか、削除、卒業はこのコマンドの対象外。
EOF
  exit 2
}

[ $# -ge 1 ] || usage
command="$1"; shift
[ "$command" = "promote" ] || { echo "不明なサブコマンド: $command" >&2; usage; }
[ $# -ge 1 ] || usage
source_input="$1"; shift

destination=""
commit=0
apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    --to) destination="${2:-}"; shift 2 ;;
    --apply) apply=1; shift ;;
    --commit) commit=1; shift ;;
    -h|--help) usage ;;
    *) echo "不明なオプション: $1" >&2; usage ;;
  esac
done

[ "$destination" = "active" ] || { echo "--to active を指定してください" >&2; exit 2; }
[ "$apply" = 0 ] || [ "$commit" = 0 ] || { echo "--apply と --commit は同時に指定できません" >&2; exit 2; }
[ -d "$source_input" ] || { echo "計画フォルダが見つからない: $source_input" >&2; exit 1; }

source_dir="$(cd "$source_input" && pwd -P)"
planning_dir="$(dirname "$source_dir")"
[ "$(basename "$planning_dir")" = "planning" ] || {
  echo "plans/planning/直下の計画フォルダだけを昇格できます: $source_dir" >&2; exit 2;
}
plans_dir="$(dirname "$planning_dir")"
active_dir="$plans_dir/active"
[ -d "$active_dir" ] || { echo "active バケットが見つからない: $active_dir" >&2; exit 1; }
target_dir="$active_dir/$(basename "$source_dir")"
[ ! -e "$target_dir" ] || { echo "昇格先が既に存在します: $target_dir" >&2; exit 1; }

repo_root="$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "対象repoが見つからない（gitリポジトリ配下ではない）: $source_dir" >&2; exit 1;
}

active_count=0
active_names=()
for d in "$active_dir"/*; do
  [ -d "$d" ] || continue
  active_count=$((active_count + 1))
  active_names+=("$(basename "$d")")
done
if [ "$active_count" -ge "$LIMIT" ]; then
  echo "active は上限${LIMIT}件です（現在${active_count}件）。先に指揮官が paused/archive へ移す計画を選んでください。" >&2
  if [ "${#active_names[@]}" -gt 0 ]; then
    printf '  - %s\n' "${active_names[@]}" >&2
  fi
  exit 1
fi

source_rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$source_dir" "$repo_root")"
target_rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$target_dir" "$repo_root")"

if [ "$apply" = 0 ] && [ "$commit" = 0 ]; then
  echo "── dry-run"
  echo "git -C $repo_root mv -- $source_rel $target_rel"
  echo "active: ${active_count}/${LIMIT} → $((active_count + 1))/${LIMIT}"
  exit 0
fi

if [ "$commit" = 1 ] && [ -n "$(git -C "$repo_root" status --porcelain -- "$source_rel")" ]; then
  echo "昇格元に未コミット変更があるため --commit を拒否します。先に整理するか --apply を使ってください: $source_rel" >&2
  exit 1
fi

git -C "$repo_root" mv -- "$source_rel" "$target_rel"
if [ "$apply" = 1 ]; then
  echo "適用済み（未コミット）: $repo_root ($target_rel)"
  exit 0
fi
git -C "$repo_root" commit --only -m "bucketctl: $(basename "$source_dir") をactiveへ昇格" -- "$source_rel" "$target_rel"
echo "commit済み: $repo_root ($target_rel)"
