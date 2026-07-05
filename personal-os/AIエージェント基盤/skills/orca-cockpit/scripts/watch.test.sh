#!/usr/bin/env bash
# orca-cockpit / watch.sh のテスト
# 合成fixture(__tests__/fixtures/*.json)のみを使用。実個人情報・実secretは含まない。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH="$HERE/watch.sh"
FIX="$HERE/__tests__/fixtures"
LANE_PATH="/synthetic/lane-a"

pass=0
fail=0

assert_eq(){ # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    pass=$((pass+1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail+1)); printf '[FAIL] %s: expected [%s] got [%s]\n' "$1" "$3" "$2"
  fi
}

assert_contains(){ # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    pass=$((pass+1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail+1)); printf '[FAIL] %s: expected to contain [%s]\n  got: %s\n' "$1" "$3" "$2"
  fi
}

# (a) err即exit
out=$(WATCH_PS_CMD="cat $FIX/err.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(a) err exit code" "$code" "0"
assert_contains "(a) err message" "$out" "WAKE[lane-a]: ペインがerror/failed/crashed(即対応)"

# (b) 人間確認待ちマーカーで即exit
out=$(WATCH_PS_CMD="cat $FIX/marker.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(b) marker exit code" "$code" "0"
assert_contains "(b) marker message" "$out" "WAKE[lane-a]: 人間確認待ちマーカー検知(段階:…最終行)"

# (c) waiting連続2回でexit
out=$(WATCH_PS_CMD="cat $FIX/waiting.json" WATCH_POLL=0 WATCH_WAIT_N=2 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(c) waiting exit code" "$code" "0"
assert_contains "(c) waiting message" "$out" "WAKE[lane-a]: 権限確認/質問待ちが約2分継続(要解除)"

# (d) alldone連続4回でexit
out=$(WATCH_PS_CMD="cat $FIX/alldone.json" WATCH_POLL=0 WATCH_STALL_N=4 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(d) alldone exit code" "$code" "0"
assert_contains "(d) alldone message" "$out" "WAKE[lane-a]: 全ペインidleが約4分継続(完了マーカー無し or 停滞)"

# (e) busy連続N回でexit（閾値を小さくして高速検証）
out=$(WATCH_PS_CMD="cat $FIX/busy.json" WATCH_POLL=0 WATCH_BUSY_N=3 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(e) busy exit code" "$code" "0"
assert_contains "(e) busy message" "$out" "WAKE[lane-a]: 約25分連続稼働(中間報告のハートビート/異常ではない)"

# (f) WATCH_MAXタイムアウト
out=$(WATCH_PS_CMD="cat $FIX/busy.json" WATCH_POLL=0 WATCH_MAX=0 WATCH_BUSY_N=999999 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(f) timeout exit code" "$code" "0"
assert_contains "(f) timeout message" "$out" "WAKE: 3時間タイムアウト(進捗未達・要点検)"

# (g) PARSE_ERRで1周スキップ後、タイムアウトへ抜ける（クラッシュしないことの確認）
out=$(WATCH_PS_CMD="cat $FIX/malformed.json" WATCH_POLL=0 WATCH_MAX=1 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(g) parse-err exit code" "$code" "0"
assert_contains "(g) parse-err message" "$out" "WAKE: 3時間タイムアウト(進捗未達・要点検)"

# (h) 複数レーン: レーン2個registerして、レーン2(lane-b)のerrで exitし WAKE[lane-b] を返す
out=$(WATCH_PS_CMD="cat $FIX/multi_second_err.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "/synthetic/lane-a" "/synthetic/lane-b" 2>/dev/null)
code=$?
assert_eq "(h) multi-lane exit code" "$code" "0"
assert_contains "(h) multi-lane message" "$out" "WAKE[lane-b]: ペインがerror/failed/crashed(即対応)"

# (i) 終端アンカー偽陽性の負例: 本文中に「段階: 人間確認待ち」を含むが最終行ではない
# （v0.4実運用の誤検知の再現）→ マーカーWAKEしないこと。busy継続のままWATCH_MAXタイムアウトへ抜けるはず。
out=$(WATCH_PS_CMD="cat $FIX/false_positive_marker.json" WATCH_POLL=0 WATCH_MAX=1 WATCH_BUSY_N=999999 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(i) false-positive marker exit code" "$code" "0"
assert_contains "(i) false-positive marker: マーカーWAKEしていない(timeoutへ抜ける)" "$out" "WAKE: 3時間タイムアウト(進捗未達・要点検)"
if printf '%s' "$out" | grep -qF "人間確認待ちマーカー検知"; then
  fail=$((fail+1)); printf '[FAIL] (i) false-positive marker: 誤ってマーカーWAKEした: %s\n' "$out"
else
  pass=$((pass+1)); printf '[PASS] (i) false-positive marker: マーカー誤検知なし\n'
fi

# (j) 完了マーカー(_DONE)最終行で即exit
out=$(WATCH_PS_CMD="cat $FIX/done_marker.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(j) done-marker exit code" "$code" "0"
assert_contains "(j) done-marker message" "$out" "WAKE[lane-a]: 完了/レビューマーカー検知(_DONE/REVIEW_RESULT:最終行)"

# (k) WATCH_SEENで処理済みマーカーを除外→停滞検知(全ペインidle)へ格下げ
out=$(WATCH_PS_CMD="cat $FIX/done_marker.json" WATCH_POLL=0 WATCH_STALL_N=4 WATCH_MAX=5 WATCH_SEEN="CHILD07_DONE" "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(k) seen-suppress exit code" "$code" "0"
assert_contains "(k) seen-suppress: 停滞検知へ格下げ" "$out" "WAKE[lane-a]: 全ペインidleが約4分継続(完了マーカー無し or 停滞)"
if printf '%s' "$out" | grep -qF "完了/レビューマーカー検知"; then
  fail=$((fail+1)); printf '[FAIL] (k) seen-suppress: 処理済みマーカーで誤WAKEした\n'
else
  pass=$((pass+1)); printf '[PASS] (k) seen-suppress: 処理済みマーカーの誤WAKEなし\n'
fi

# (l) REVIEW_RESULT: PASS 最終行で即exit
out=$(WATCH_PS_CMD="cat $FIX/review_marker.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(l) review-marker exit code" "$code" "0"
assert_contains "(l) review-marker message" "$out" "完了/レビューマーカー検知"

# (m) 終端アンカー負例: _DONEが本文中(最終行でない)ならマーカーWAKEしない
out=$(WATCH_PS_CMD="cat $FIX/false_positive_done.json" WATCH_POLL=0 WATCH_MAX=1 WATCH_BUSY_N=999999 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(m) fp-done exit code" "$code" "0"
if printf '%s' "$out" | grep -qF "完了/レビューマーカー検知"; then
  fail=$((fail+1)); printf '[FAIL] (m) fp-done: 本文中マーカーで誤WAKEした: %s\n' "$out"
else
  pass=$((pass+1)); printf '[PASS] (m) fp-done: 本文中マーカーの誤検知なし\n'
fi

# (n) working継続+画面シグネチャ(利用上限/セレクタ)で即exit
out=$(WATCH_PS_CMD="cat $FIX/busy.json" WATCH_TERMS_CMD="cat $FIX/terms_dialog.json" WATCH_POLL=0 WATCH_SIG_N=2 WATCH_BUSY_N=999999 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(n) dialog-sig exit code" "$code" "0"
assert_contains "(n) dialog-sig message" "$out" "WAKE[lane-a]: working継続中に対話ダイアログ/利用上限の画面シグネチャ検知(ペイン解除が必要)"

# (o) working継続でも画面が正常ならシグネチャWAKEしない(タイムアウトへ抜ける)
out=$(WATCH_PS_CMD="cat $FIX/busy.json" WATCH_TERMS_CMD="cat $FIX/terms_clean.json" WATCH_POLL=0 WATCH_SIG_N=2 WATCH_BUSY_N=999999 WATCH_MAX=1 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(o) clean-screen exit code" "$code" "0"
if printf '%s' "$out" | grep -qF "画面シグネチャ検知"; then
  fail=$((fail+1)); printf '[FAIL] (o) clean-screen: 正常画面で誤WAKEした\n'
else
  pass=$((pass+1)); printf '[PASS] (o) clean-screen: シグネチャ誤検知なし\n'
fi

# (p) シグネチャがあってもworking継続がWATCH_SIG_N未満なら見ない(ゲート確認)
out=$(WATCH_PS_CMD="cat $FIX/busy.json" WATCH_TERMS_CMD="cat $FIX/terms_dialog.json" WATCH_POLL=0 WATCH_SIG_N=999999 WATCH_BUSY_N=999999 WATCH_MAX=1 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(p) sig-gate exit code" "$code" "0"
if printf '%s' "$out" | grep -qF "画面シグネチャ検知"; then
  fail=$((fail+1)); printf '[FAIL] (p) sig-gate: 閾値未満でシグネチャWAKEした\n'
else
  pass=$((pass+1)); printf '[PASS] (p) sig-gate: 閾値未満では画面を見ない\n'
fi

# (q) 自動レビュー配布v1: 実装_DONE+2ペイン → レビューペインへ自動send・マーカーWAKEせず監視継続
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_marker_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_2pane.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" \
  WATCH_POLL=0 WATCH_MAX=1 WATCH_BUSY_N=999999 WATCH_SIG_N=999999 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(q) auto-review exit code" "$code" "0"
assert_contains "(q) auto-review: マーカーWAKEせずタイムアウトへ抜ける" "$out" "WAKE: 3時間タイムアウト(進捗未達・要点検)"
if printf '%s' "$out" | grep -qF "完了/レビューマーカー検知"; then
  fail=$((fail+1)); printf '[FAIL] (q) auto-review: 自動配布のはずがマーカーWAKEした: %s\n' "$out"
else
  pass=$((pass+1)); printf '[PASS] (q) auto-review: マーカーWAKEなし\n'
fi
assert_eq "(q) auto-review: sendは1回だけ(再検知抑止)" "$(grep -c '^send ' "$SLOG")" "1"
assert_contains "(q) auto-review: レビューペインhandleへ送信" "$(cat "$SLOG")" "--terminal term_rev_1"
assert_contains "(q) auto-review: 検知マーカーがプロンプトに入る" "$(cat "$SLOG")" "CHILD07_DONE"
assert_contains "(q) auto-review: stage=レビューを宣言" "$(cat "$SLOG")" "--stage レビュー"
rm -f "$SLOG"

# (r) WATCH_AUTO_REVIEW=0: 従来どおり即WAKE・sendは呼ばれない
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_marker_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_2pane.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" WATCH_AUTO_REVIEW=0 \
  WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(r) opt-out exit code" "$code" "0"
assert_contains "(r) opt-out: 従来どおり即WAKE" "$out" "完了/レビューマーカー検知"
assert_eq "(r) opt-out: sendは呼ばれない" "$(grep -c '^send ' "$SLOG")" "0"
rm -f "$SLOG"

# (s) ペイン特定不可(terminal突合できない) → 従来WAKEへフォールバック・sendは呼ばれない
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_marker_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_clean.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" \
  WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(s) resolve失敗 exit code" "$code" "0"
assert_contains "(s) resolve失敗: 従来WAKEへフォールバック" "$out" "完了/レビューマーカー検知"
assert_eq "(s) resolve失敗: sendは呼ばれない" "$(grep -c '^send ' "$SLOG")" "0"
rm -f "$SLOG"

# (t) send失敗(非0終了) → 従来WAKEへフォールバック・試行1回は記録される
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_marker_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_2pane.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" SEND_STUB_RC=1 \
  WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(t) send失敗 exit code" "$code" "0"
assert_contains "(t) send失敗: 従来WAKEへフォールバック" "$out" "完了/レビューマーカー検知"
assert_eq "(t) send失敗: 試行は1回記録される" "$(grep -c '^send ' "$SLOG")" "1"
rm -f "$SLOG"

# (u) 1ペイン構成(既存done_marker.json)は自動配布せず従来WAKE（既定ON下での(j)の恒常性確認）
out=$(WATCH_PS_CMD="cat $FIX/done_marker.json" WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(u) 1ペイン exit code" "$code" "0"
assert_contains "(u) 1ペイン: 自動配布せず従来WAKE" "$out" "完了/レビューマーカー検知"

# (v) 差し戻し1所見2: 未処理REVIEW_RESULTが実装_DONEと併存(watch再起動後・実装pane先頭の並び)なら
# 自動配布せずREVIEW_RESULTを優先して即WAKE
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_and_review_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_2pane.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" \
  WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(v) REVIEW_RESULT優先 exit code" "$code" "0"
assert_contains "(v) REVIEW_RESULT優先: 自動配布せず即WAKE" "$out" "完了/レビューマーカー検知"
assert_contains "(v) REVIEW_RESULT優先: 検知行はREVIEW_RESULT側" "$out" "REVIEW_RESULT: PASS"
assert_eq "(v) REVIEW_RESULT優先: sendは呼ばれない" "$(grep -c '^send ' "$SLOG")" "0"
rm -f "$SLOG"

# (w) 差し戻し1所見1: paneKey×terminal突合が複数一致なら曖昧=中止して従来WAKE(誤送信防止)
SLOG=$(mktemp)
out=$(WATCH_PS_CMD="cat $FIX/done_marker_2pane.json" WATCH_TERMS_CMD="cat $FIX/terms_dup_pane.json" \
  WATCH_SEND_CMD="$HERE/__tests__/send_stub.sh" SEND_STUB_LOG="$SLOG" \
  WATCH_POLL=0 WATCH_MAX=5 "$WATCH" "$LANE_PATH" 2>/dev/null)
code=$?
assert_eq "(w) 突合複数一致 exit code" "$code" "0"
assert_contains "(w) 突合複数一致: 中止して従来WAKE" "$out" "完了/レビューマーカー検知"
assert_eq "(w) 突合複数一致: sendは呼ばれない" "$(grep -c '^send ' "$SLOG")" "0"
rm -f "$SLOG"

printf '\n合計: %d pass / %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
