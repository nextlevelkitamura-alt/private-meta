#!/usr/bin/env bash
# plan-ops / progctl — program.md の「子計画マップ」を対象NNブロックだけ機械書換する。
#
# 痛点対策: マップ手動更新（Edit+コミット）が当日コミットの過半を占める実測を受け、
#           何を書くか（状態文言・次の一手・参照repo@hash）は人間/指揮官の判断のまま、
#           「該当NNブロックだけを冪等に書き換える」手だけを機械化する。
# 規律: マップ外・他NNブロックはバイト不変（書換コアはprogctl_core.py、areas/AGENTS.md §3準拠のパーサ）。
#       既定はdry-run（unified diffのみ表示・書き込みしない）。--commitで書換+定型コミット。
set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
usage: progctl.sh set <program.mdのパス> <NN> [--state <文言>] [--next <文言>] [--ref <repo>@<hash>] [--commit]
  set        該当NN（2桁）のブロックだけを冪等に書き換える。--state/--next/--refの少なくとも1つが必須。
  --state    見出し行「NN  <名前> … <状態>」の<状態>部分を丸ごと置換する（注記の要否含め呼び出し元が決める）。
  --next     ブロック本体の「次: 」行を置換、無ければ「場所:」行の直前に新設する。
  --ref      ブロック本体の「参照: 」行（<repo>@<hash>形式）を置換、無ければ「場所:」行の直前に新設する。
             2repo束ね（基盤マージ↔マップ更新）のコミットペアで相手hashを機械的に記録する専用フィールド。
  --commit   書換を実ファイルへ適用し、対象repoで定型コミットする（既定はdry-runでunified diffのみ表示）。

既に同じ内容ならdry-run/--commitとも「変更なし（冪等）」を出して終了（差分0・空コミットを作らない）。
EOF
  exit 2
}

[ $# -ge 1 ] || usage
cmd="$1"; shift
[ "$cmd" = "set" ] || { echo "不明なサブコマンド: $cmd" >&2; usage; }

[ $# -ge 2 ] || usage
program="$1"; nn="$2"; shift 2

state="" ; have_state=0
next="" ; have_next=0
ref="" ; have_ref=0
commit=0

while [ $# -gt 0 ]; do
  case "$1" in
    --state) state="${2:-}"; have_state=1; shift 2;;
    --next)  next="${2:-}"; have_next=1; shift 2;;
    --ref)   ref="${2:-}"; have_ref=1; shift 2;;
    --commit) commit=1; shift;;
    -h|--help) usage;;
    *) echo "不明なオプション: $1" >&2; usage;;
  esac
done

[ -f "$program" ] || { echo "program.mdが見つからない: $program" >&2; exit 1; }
case "$nn" in
  [0-9][0-9]) ;;
  *) echo "NNは2桁数字で指定: $nn" >&2; exit 2;;
esac
if [ "$have_state" = 0 ] && [ "$have_next" = 0 ] && [ "$have_ref" = 0 ]; then
  echo "--state/--next/--refのいずれか1つ以上が必須" >&2; usage
fi
if [ "$have_ref" = 1 ]; then
  case "$ref" in
    *@*) ;;
    *) echo "--refは <repo>@<hash> 形式で指定: $ref" >&2; exit 2;;
  esac
fi

py_args=(--program "$program" --nn "$nn")
[ "$have_state" = 1 ] && py_args+=(--state "$state")
[ "$have_next" = 1 ] && py_args+=(--next "$next")
[ "$have_ref" = 1 ] && py_args+=(--ref "$ref")

tmp="$(mktemp "${TMPDIR:-/tmp}/progctl.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

python3 "$SELFDIR/progctl_core.py" "${py_args[@]}" > "$tmp"

if cmp -s "$program" "$tmp"; then
  echo "変更なし（冪等）: $program #$nn"
  exit 0
fi

if [ "$commit" = 1 ]; then
  cp "$tmp" "$program"
  repo_root="$(git -C "$(dirname "$program")" rev-parse --show-toplevel)" || {
    echo "対象repoが見つからない（gitリポジトリ配下ではない）: $program" >&2; exit 1;
  }
  rel="$(python3 -c "import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), os.path.realpath(sys.argv[2])))" "$program" "$repo_root")"
  summary=""
  [ "$have_state" = 1 ] && summary="${summary} state=${state}"
  [ "$have_next" = 1 ]  && summary="${summary} next=${next}"
  [ "$have_ref" = 1 ]   && summary="${summary} ref=${ref}"
  git -C "$repo_root" add "$rel"
  git -C "$repo_root" commit -m "progctl: $(basename "$program") #${nn}${summary}"
  echo "commit済み: $repo_root ($rel #${nn})"
else
  diff -u "$program" "$tmp" || true
  echo "── dry-run（--commitで書換+コミット）"
fi
