#!/bin/zsh
# llm-judge — board-sweep の SWEEP_LLM_CMD 用ラッパ（stdin=プロンプト → codex exec → stdout=JSON）。
#
# 判定エージェントは read-only 設計（custom-agent-creator quality-gate 指針: 判定のみ・編集させない）:
#   --sandbox read-only … モデルにファイル編集・破壊コマンドを実行させない
#   --ephemeral         … 判定セッションを ~/.codex/sessions に残さない（sweep の実体照合を汚さない）
#   AIJOBS_RUN=1        … session-board フックに自己登録しない（sweep.sh からの継承に加え自前でも保険）
#
# モデルはハードコードしない（差し替え口2つ・確定は人間ゲート）:
#   引数 $1 > 環境変数 SWEEP_LLM_MODEL。どちらも無ければ exit 78 で降りる
#   （sweep.py 側は LLM失敗＝全行 unknown・不流入＝無害）。
# 例: echo "<プロンプト>" | SWEEP_LLM_MODEL=gpt-5.6-luna scripts/llm-judge.sh
set -u
export AIJOBS_RUN=1

MODEL="${1:-${SWEEP_LLM_MODEL:-}}"
if [[ -z "$MODEL" ]]; then
  echo "llm-judge: モデル未指定（引数 or SWEEP_LLM_MODEL を設定。実名の確定は人間ゲート）" >&2
  exit 78
fi

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# 進行ログは stderr へ流し、stdout には最終メッセージ（JSONオブジェクト）だけを出す。
# タイムアウトは呼び出し元 sweep.py（SWEEP_LLM_TIMEOUT・既定180秒）が持つ。
# reasoning effort は既定 medium（config の high を上書き。判定は読解タスクで、
# 低effortでも仕様上 unknown 側に倒れるだけ＝安全。SWEEP_LLM_EFFORT で差替可）。
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never \
  -c "model_reasoning_effort=\"${SWEEP_LLM_EFFORT:-medium}\"" \
  -m "$MODEL" -o "$OUT" - >&2 || exit $?
cat "$OUT"
