#!/usr/bin/env bash
# plan-ops / jobctl — ai-jobs の run-card 状態遷移を固定パスで安全に行う。
#
# 痛点①対策: claim/done の mv はカレントディレクトリに依存しない。
#            base を絶対パスで固定するので、どこから呼んでも同じ動作。
# 規律: 状態=フォルダ位置（ai-jobs/AGENTS.md §1）。上書きしない・削除しない・差し戻しは ready へ。
set -euo pipefail

AIJOBS="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs"
STATES="ready running review reviewing done archive"

usage() {
  cat >&2 <<'EOF'
usage: jobctl <cmd> [card]
  ls [state]      状態フォルダの中身を列挙（state省略で全状態のサマリ）
  claim <card>    ready     -> running    実行を掴む（OSレベルでアトミック＝奪い合い防止）
  review <card>   running   -> review      実装完了・レビュー待ちへ
  take <card>     review    -> reviewing   レビューを取得（アトミック＝二重レビュー防止）
  done <card>     running|reviewing -> done   完了（running=review不要 / reviewing=レビュー合格）
  back <card>     running|review|reviewing -> ready   差し戻し（削除しない）
state: ready | running | review | reviewing | done | archive
base : ai-jobs（固定・cwd非依存）
EOF
  exit 2
}

ensure_dirs() { for s in $STATES; do [ -d "$AIJOBS/$s" ] || mkdir -p "$AIJOBS/$s"; done; }

# locate <card> <state...> : card を含む最初の state を echo（無ければ空・exitしない）
locate() {
  local card="$1"; shift
  local s
  for s in "$@"; do [ -e "$AIJOBS/$s/$card" ] && { printf '%s' "$s"; return 0; }; done
  return 0
}

# move <from> <to> <card>
move() {
  local from="$1" to="$2" card="$3"
  [ -n "$card" ] || { echo "card名が必要" >&2; exit 2; }
  [ -e "$AIJOBS/$from/$card" ] || { echo "見つからない: $from/$card" >&2; exit 1; }
  [ -e "$AIJOBS/$to/$card" ] && { echo "既に存在: $to/$card（上書きしない）" >&2; exit 1; }
  mv "$AIJOBS/$from/$card" "$AIJOBS/$to/$card"
  echo "$card: $from → $to"
}

# from_one <to> <card> <candidate-from...> : 複数候補から実在する元を見つけて move
from_one() {
  local to="$1" card="$2"; shift 2
  [ -n "$card" ] || { echo "card名が必要" >&2; exit 2; }
  local from; from="$(locate "$card" "$@")"
  [ -n "$from" ] || { echo "見つからない: $card（探索: $*）" >&2; exit 1; }
  move "$from" "$to" "$card"
}

ensure_dirs
cmd="${1:-}"; card="${2:-}"
case "$cmd" in
  ls)
    if [ -n "$card" ]; then
      ls -1 "$AIJOBS/$card" 2>/dev/null | grep -v '^\.gitkeep$' || true
    else
      for s in $STATES; do
        n=$(ls -1 "$AIJOBS/$s" 2>/dev/null | grep -vc '^\.gitkeep$' || true)
        echo "$s: $n"
        ls -1 "$AIJOBS/$s" 2>/dev/null | grep -v '^\.gitkeep$' | sed 's/^/  /' || true
      done
    fi ;;
  claim)  move ready running "$card" ;;
  review) move running review "$card" ;;
  take)   move review reviewing "$card" ;;
  done)   from_one done "$card" running reviewing ;;
  back)   from_one ready "$card" running review reviewing ;;
  ""|-h|--help|help) usage ;;
  *) echo "不明なcmd: $cmd" >&2; usage ;;
esac
