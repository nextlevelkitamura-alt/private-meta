#!/usr/bin/env bash
# renderer / build-board-wait — auto:board-wait マーカーへ差し込む「待ち」本文を組み立てる。
#
# 3種を決定的に出す（AIを呼ばない）:
#   1. 人間確認待ち: orca ps の lastAssistantMessage 最終行に「人間確認待ち」を含むagent。
#   2. 着手可能: program.md 子計画マップで状態が「計画」(実装未着手)の子。
#   3. 未紐付け:
#      a. レーン — orca ps のworktreeで displayName に「子NN」パターンが無いもの
#         （orca-cockpit運用規約: 起動時にdisplayName＝計画名(子NN)を入れる）。
#      b. コミット — auto:log（既にpull済みのClaude当日セッション。cwd/commitsフィールド持ち）の
#         cwdが、orca psのどのレーンpathにも属さないもの（新規git走査を増やさず既存pullデータを再利用）。
#         「属する」はcwdとレーンpathの完全一致に加え、cwdがレーンpath配下のサブディレクトリ
#         （例: worktree直下でなくサブフォルダでセッションを開いた通常ケース）である場合も含む
#         （差し戻し1回目・指摘1: 完全一致のみだとサブディレクトリcwdを誤って未紐付け判定していた）。
#
# 部品（orca-ps-snapshot.sh / plan-scan.sh）の失敗は握りつぶさず非0で終了する（render.sh側の
# 『builder失敗→applyスキップ・既存内容保持』防御に乗せるため）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"

daily_file="${1:?usage: build-board-wait.sh <daily-file>}"

status=0

snapshot=""
if ! snapshot="$("$SCRIPT_DIR/orca-ps-snapshot.sh")"; then
  echo "警告: orca-ps-snapshot.sh が失敗した（auto:board-waitの人間確認待ち・未紐付けレーン検出をスキップ）" >&2
  status=1
fi

plans=""
if ! plans="$("$SCRIPT_DIR/plan-scan.sh")"; then
  echo "警告: plan-scan.sh が失敗した（auto:board-waitの着手可能検出をスキップ）" >&2
  status=1
fi

waiting_confirm=""
unlinked_lanes=""
known_paths=""
if [ -n "$snapshot" ]; then
  known_paths="$(printf '%s\n' "$snapshot" | awk -F'|' '{ print $1 }' | sort -u)"
  while IFS='|' read -r path worktree display branch wstatus agent_type state lastline; do
    [ -n "$path" ] || continue
    label="${display:-$worktree}"
    if [ -n "$lastline" ] && printf '%s' "$lastline" | grep -qF "人間確認待ち"; then
      waiting_confirm="${waiting_confirm}- [auto] 人間確認待ち: ${label}（${worktree}） ／ ${lastline}
"
    fi
    if ! printf '%s' "$display" | grep -qE '子[0-9]+'; then
      unlinked_lanes="${unlinked_lanes}- [auto] 未紐付けレーン: ${worktree}（displayName:${display:-未設定}）
"
    fi
  done <<< "$snapshot"
  # 1レーン内に複数agentがいる場合、未紐付け行が重複しうるので去重する。
  if [ -n "$unlinked_lanes" ]; then
    unlinked_lanes="$(printf '%s' "$unlinked_lanes" | awk '!seen[$0]++')
"
  fi
fi

ready_to_start=""
if [ -n "$plans" ]; then
  while IFS='|' read -r kind no name cstatus program_title; do
    [ "$kind" = "child" ] || continue
    if [ "$cstatus" = "計画" ]; then
      ready_to_start="${ready_to_start}- [auto] 着手可能: ${program_title} 子${no} ${name}
"
    fi
  done <<< "$plans"
fi

# cwdがknown_paths（orca psのレーンpath群）のいずれかと完全一致、または
# いずれかのpath配下のサブディレクトリなら「紐付いている」とみなす。
# 末尾スラッシュはpath・cwd双方とも正規化してから比較する。
is_known_lane_path() {
  local target="$1" p
  [ -n "$known_paths" ] || return 1
  target="${target%/}"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    p="${p%/}"
    if [ "$target" = "$p" ]; then
      return 0
    fi
    case "$target" in
      "$p"/*) return 0 ;;
    esac
  done <<< "$known_paths"
  return 1
}

unlinked_commits=""
log_lines=""
if log_lines="$("$DAILY_DIGEST_SCRIPTS/get-marker-block.sh" "$daily_file" log 2>/dev/null)"; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in *"cwd="*) : ;; *) continue ;; esac
    cwd="$(printf '%s' "$line" | awk -F'|' '
      { for (i = 1; i <= NF; i++) { f = $i; gsub(/^[ \t]+|[ \t]+$/, "", f)
          if (index(f, "cwd=") == 1) { print substr(f, 5); exit } } }')"
    commits="$(printf '%s' "$line" | awk -F'|' '
      { for (i = 1; i <= NF; i++) { f = $i; gsub(/^[ \t]+|[ \t]+$/, "", f)
          if (index(f, "commits=") == 1) { print substr(f, 9); exit } } }')"
    [ -n "$cwd" ] || continue
    [ -n "$commits" ] || continue
    if is_known_lane_path "$cwd"; then
      continue
    fi
    unlinked_commits="${unlinked_commits}- [auto] 未紐付けコミット: ${cwd} ／ commits=${commits}
"
  done <<< "$log_lines"
fi

out=""
[ -n "$waiting_confirm" ] && out="${out}${waiting_confirm}"
[ -n "$ready_to_start" ] && out="${out}${ready_to_start}"
[ -n "$unlinked_lanes" ] && out="${out}${unlinked_lanes}"
[ -n "$unlinked_commits" ] && out="${out}${unlinked_commits}"

if [ -z "$out" ]; then
  echo "- [auto] 待ちなし。"
else
  printf '%s' "$out"
fi

exit "$status"
