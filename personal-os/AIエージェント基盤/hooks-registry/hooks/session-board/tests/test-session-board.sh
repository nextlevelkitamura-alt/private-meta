#!/bin/bash
# session-board 再設計のテスト（env差し替え・実ボードに触れない）
# パスはスクリプト位置から相対解決（worktree でもそのまま動く）
set -u
SB="$(cd "$(dirname "$0")/.." && pwd)"
CL="$(cd "$(dirname "$0")/../../../claude" && pwd)"
CX="$(cd "$(dirname "$0")/../../../codex" && pwd)"
SP="$(mktemp -d)/sbtest"   # 作業ゴミは tests/ でなく tmp へ（tests/ を汚さない）
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-01" SESSION_BOARD_TX_ROOTS="$SP/tx"
BOARD="$SB/board.py"
DAILY="$SP/goal/2099/01/2099-01-01.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }
grepq(){ grep -qF -- "$1" "$DAILY"; }

echo "=== 1. add: 新形式の枠行 ==="
"$BOARD" add --key aaaa0001 --repo RepoA --who "claude/?" --time 14:00
ok "add新形式行" grepq "- 🟢 14:00 | ? | 今:? | RepoA | その他 | claude/? | 計画:? <!-- s:aaaa0001 -->"

echo "=== 2. update: goal/now/type/model 反映・時刻不変 ==="
"$BOARD" update --key aaaa0001 --type 実装 --goal "ボード再設計" --now "board.py改修" --model fable5
ok "update反映" grepq "- 🟢 14:00 | ボード再設計 | 今:board.py改修 | RepoA | 実装 | claude/fable5 | 計画:? <!-- s:aaaa0001 -->"

echo "=== 3. add冪等: 既存行を上書きしない ==="
"$BOARD" add --key aaaa0001 --repo RepoX --who "codex/?"
ok "add冪等(内容不変)" grepq "| ボード再設計 | 今:board.py改修 | RepoA | 実装 | claude/fable5 | 計画:? <!-- s:aaaa0001 -->"

echo "=== 4. show / goals / check ==="
SHOW="$("$BOARD" show --key aaaa0001)"
[ "$SHOW" = "$(printf 'run\tボード再設計\tboard.py改修\t実装\tRepoA\tclaude/fable5\t?')" ]; ok "show出力(7フィールド)" test $? -eq 0
[ "$("$BOARD" check --key aaaa0001)" = "run" ]; ok "check=run" test $? -eq 0
[ "$("$BOARD" goals)" = "ボード再設計" ]; ok "goals一覧" test $? -eq 0

echo "=== 5. flip ==="
"$BOARD" flip --key aaaa0001 --state sub
[ "$("$BOARD" check --key aaaa0001)" = "sub" ]; ok "flip sub" test $? -eq 0
"$BOARD" flip --key aaaa0001 --state run

echo "=== 6. goals-summary と 同目標の隣接ソート ==="
"$BOARD" add --key bbbb0002 --repo RepoA --who "codex/?" --time 14:05
"$BOARD" update --key bbbb0002 --type 実装 --goal "ボード再設計" --now "README改稿" --model kimi2.6
"$BOARD" add --key cccc0003 --repo RepoB --who "claude/?" --time 11:00
"$BOARD" update --key cccc0003 --type リサーチ --goal "求人PDF整理" --now "規則確認"
"$BOARD" flip --key cccc0003 --state wait
ok "summary目標1" grepq "- ボード再設計 — 2体（🟢2）"
ok "summary目標2" grepq "- 求人PDF整理 — 1体（⏸1）"
# 並び: summaryブロックの後、ボード再設計2行(aaaa,bbbb) → 求人PDF整理(cccc)
ORDER=$(grep -o 's:[a-z0-9]*' "$DAILY" | head -3 | tr '\n' ' ')
[ "$ORDER" = "s:aaaa0001 s:bbbb0002 s:cccc0003 " ]; ok "ソート順(生存グループ→時刻)" test $? -eq 0

echo "=== 7. log: (+Nm) 自動付与 ==="
"$BOARD" log --key aaaa0001 --repo RepoA --parent "ボード再設計" --time 14:38 --entry "board.py改修完了"
ok "log初回(+38m/開始14:00起点)" grepq "  - 14:38 (+38m) board.py改修完了"
"$BOARD" log --key aaaa0001 --repo RepoA --parent "ボード再設計" --time 15:20 --entry "common.py改修完了" --entry "受け口4本更新"
ok "log2回目(+42m/前節目起点)" grepq "  - 15:20 (+42m) common.py改修完了"
ok "log複数entry(2つ目はmarkなし)" grepq "  - 15:20 受け口4本更新"

echo "=== 8. 日跨ぎ (+Nm) ==="
"$BOARD" add --key dddd0004 --repo RepoC --who "claude/?" --time 23:50
"$BOARD" update --key dddd0004 --goal "夜間バッチ" --now "実行"
"$BOARD" log --key dddd0004 --repo RepoC --parent "夜間バッチ" --time 00:10 --entry "完了"
ok "日跨ぎ(+20m)" grepq "  - 00:10 (+20m) 完了"

echo "=== 9. finish: 行削除＋子追記 ==="
"$BOARD" finish --key dddd0004 --repo RepoC --parent "夜間バッチ" --time 00:15 --entry "締め"
ok "finish行削除" bash -c "! grep -qF 's:dddd0004' '$DAILY'"
ok "finish子追記(+5m)" grepq "  - 00:15 (+5m) 締め"

# aaaa0001/bbbb0002 は実働セッション＝実体トランスクリプトあり（幽霊枠掃除の対象外・以降のreconcileはmtimeで判定）
touch "$SP/tx/proj/aaaa0001-x.jsonl" "$SP/tx/proj/bbbb0002-y.jsonl"

echo "=== 10. 旧形式の読み互換と自動移行 ==="
cat >> "$DAILY" <<'EOF'
EOF
# 旧形式行を「動いているエージェント」節へ手で差し込む（sed で見出し直後に挿入）
python3 - "$DAILY" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
i = lines.index("## 動いているエージェント")
lines.insert(i + 1, "- 09:15 | OldRepo | 計画 | 旧形式の要約テキスト | 🟢動作中 <!-- s:eeee0005 -->")
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
[ "$("$BOARD" check --key eeee0005)" = "run" ]; ok "旧形式をcheckで読める" test $? -eq 0
"$BOARD" show --key eeee0005 | grep -q "旧形式の要約テキスト"; ok "旧形式をshowで読める" test $? -eq 0
touch "$SP/tx/proj/eeee0005-old.jsonl"   # 実体あり(新しい)→reconcileで降格しない
"$BOARD" reconcile
ok "旧→新形式へ移行" grepq "- 🟢 09:15 | 旧形式の要約テキスト | 今:? | OldRepo | 計画 | ? | 計画:? <!-- s:eeee0005 -->"
ok "旧形式行が残っていない" bash -c "! grep -qF '| 旧形式の要約テキスト | 🟢動作中' '$DAILY'"

echo "=== 11. reconcile: 生存照合 ==="
# 🟢 15分沈黙 → ⏸
touch -t "$(date -v-15M +%Y%m%d%H%M.%S)" "$SP/tx/proj/aaaa0001-x.jsonl"
# 🟢 3分前 → 維持
touch -t "$(date -v-3M +%Y%m%d%H%M.%S)" "$SP/tx/proj/bbbb0002-y.jsonl"
# 🔵 親ファイルは20分沈黙・サブ実体(subagents/)は1分前 → パス照合で生存維持
"$BOARD" add --key ffff0006 --repo RepoD --who "claude/?" --time 13:00
"$BOARD" update --key ffff0006 --goal "サブ委託調査" --now "委託中"
"$BOARD" flip --key ffff0006 --state sub
mkdir -p "$SP/tx/proj/ffff0006-6666-7777/subagents"
touch -t "$(date -v-20M +%Y%m%d%H%M.%S)" "$SP/tx/proj/ffff0006-6666-7777.jsonl"
touch -t "$(date -v-1M +%Y%m%d%H%M.%S)" "$SP/tx/proj/ffff0006-6666-7777/subagents/agent-abc.jsonl"
# 🔵 35分沈黙(サブごと) → ⏸
"$BOARD" add --key gggg0007 --repo RepoD --who "claude/?" --time 12:00
"$BOARD" update --key gggg0007 --goal "死んだサブ" --now "委託中"
"$BOARD" flip --key gggg0007 --state sub
mkdir -p "$SP/tx/proj/gggg0007-8888/subagents"
touch -t "$(date -v-35M +%Y%m%d%H%M.%S)" "$SP/tx/proj/gggg0007-8888.jsonl"
touch -t "$(date -v-35M +%Y%m%d%H%M.%S)" "$SP/tx/proj/gggg0007-8888/subagents/agent-dead.jsonl"
# 🔵 20分沈黙 → 30分閾値なので維持
"$BOARD" add --key hhhh0008 --repo RepoD --who "codex/?" --time 12:30
"$BOARD" update --key hhhh0008 --goal "20分サブ" --now "委託中"
"$BOARD" flip --key hhhh0008 --state sub
touch -t "$(date -v-20M +%Y%m%d%H%M.%S)" "$SP/tx/proj/hhhh0008-9999.jsonl"
"$BOARD" reconcile
[ "$("$BOARD" check --key aaaa0001)" = "wait" ]; ok "🟢15分沈黙→⏸" test $? -eq 0
[ "$("$BOARD" check --key bbbb0002)" = "run" ];  ok "🟢3分前→維持" test $? -eq 0
[ "$("$BOARD" check --key ffff0006)" = "sub" ];  ok "🔵サブ実体が新しい→維持(誤爆修正)" test $? -eq 0
[ "$("$BOARD" check --key gggg0007)" = "wait" ]; ok "🔵35分沈黙→⏸" test $? -eq 0
[ "$("$BOARD" check --key hhhh0008)" = "sub" ];  ok "🔵20分沈黙→維持(30分閾値)" test $? -eq 0

echo "=== 12. 計画参照列 v2.2（仕様D 1-8）==="
# D1: add の枠は 計画:?
"$BOARD" add --key plan0001 --repo PlanRepo --who "claude/?" --time 16:00
ok "D1 add枠=計画:?" grepq "| PlanRepo | その他 | claude/? | 計画:? <!-- s:plan0001 -->"
# D8: show が7フィールド（plan含む）
[ "$("$BOARD" show --key plan0001 | awk -F'\t' '{print NF}')" = "7" ]; ok "D8 showが7フィールド" test $? -eq 0
# D2: update --plan（短縮参照）反映 → update --plan なし 反映
"$BOARD" update --key plan0001 --goal "計画置き" --now "着手" --type 実装 --plan "計画実行フロー統一/03"
ok "D2 update --plan(参照)反映" grepq "| claude/? | 計画:計画実行フロー統一/03 <!-- s:plan0001 -->"
"$BOARD" update --key plan0001 --plan "なし"
ok "D2 update --plan なし反映" grepq "| claude/? | 計画:なし <!-- s:plan0001 -->"
# D4: log で参照計画 → 親行末尾に ‹計画: …›（参照へ戻してから）
"$BOARD" update --key plan0001 --plan "計画実行フロー統一/03"
"$BOARD" log --key plan0001 --repo PlanRepo --parent "計画置き" --time 16:20 --entry "節目1"
ok "D4 log→親行に‹計画:›付与" grepq "- 計画置き ‹計画: 計画実行フロー統一/03›"
# D5: 同じ親へ2回目の log → ‹計画: 重複しない・親は1つ（子2つが1親配下）
"$BOARD" log --key plan0001 --repo PlanRepo --parent "計画置き" --time 16:30 --entry "節目2"
[ "$(grep -cF '計画置き ‹計画:' "$DAILY")" = "1" ]; ok "D5 2回目logで‹計画:重複なし" test $? -eq 0
[ "$(grep -cE '^- 計画置き( ‹計画:|$)' "$DAILY")" = "1" ]; ok "D5 親行は重複生成されない" test $? -eq 0
grepq "  - 16:20"; ok "D5 節目1は親配下に残る" grepq "  - 16:20"
grepq "  - 16:30"; ok "D5 節目2も親配下に入る" grepq "  - 16:30"
# D7: plan=なし → 転記されない
"$BOARD" add --key plan0002 --repo PlanRepo --who "codex/?" --time 17:00
"$BOARD" update --key plan0002 --goal "サクッと" --plan "なし"
"$BOARD" log --key plan0002 --repo PlanRepo --parent "サクッと" --time 17:05 --entry "完了"
ok "D7 なしは親へ転記されない" bash -c "grep -qxF -- '- サクッと' '$DAILY'"
# D7: plan=? → 転記されない
"$BOARD" add --key plan0003 --repo PlanRepo --who "codex/?" --time 17:10
"$BOARD" update --key plan0003 --goal "未記入計画"
"$BOARD" log --key plan0003 --repo PlanRepo --parent "未記入計画" --time 17:15 --entry "完了"
ok "D7 ?は親へ転記されない" bash -c "grep -qxF -- '- 未記入計画' '$DAILY'"
# D6: finish でも同様に付与される（＋自行削除）
"$BOARD" add --key plan0004 --repo PlanRepo --who "claude/?" --time 18:00
"$BOARD" update --key plan0004 --goal "完了付与" --plan "ai運用:計画実行フロー統一/03"
"$BOARD" finish --key plan0004 --repo PlanRepo --parent "完了付与" --time 18:10 --entry "締め"
ok "D6 finishでも‹計画:›付与" grepq "- 完了付与 ‹計画: ai運用:計画実行フロー統一/03›"
ok "D6 finish自行削除" bash -c "! grep -qF 's:plan0004' '$DAILY'"
# D3: v2行（計画列なし）混在 → check/show で読める → reconcile 1回で全行 v2.2 化
python3 - "$DAILY" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
i = lines.index("## 動いているエージェント")
lines.insert(i + 1, "- 🟢 08:00 | v2混在行 | 今:確認 | V2Repo | 実装 | claude/? <!-- s:plan0005 -->")
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
[ "$("$BOARD" check --key plan0005)" = "run" ]; ok "D3 v2行をcheckで読める" test $? -eq 0
[ "$("$BOARD" show --key plan0005 | awk -F'\t' '{print $7}')" = "?" ]; ok "D3 v2行のplanは?補完でshow" test $? -eq 0
touch "$SP/tx/proj/plan0005-v2.jsonl"   # 実体あり(新しい)→reconcileで降格しない
"$BOARD" reconcile
ok "D3 reconcile1回でv2.2化" grepq "- 🟢 08:00 | v2混在行 | 今:確認 | V2Repo | 実装 | claude/? | 計画:? <!-- s:plan0005 -->"
ok "D3 v2行(計画列なし)が残らない" bash -c "! grep -qF -- '| claude/? <!-- s:plan0005 -->' '$DAILY'"

echo "=== 13. reconcile: 実体皆無の幽霊枠掃除（遅延登録の取りこぼし対策）==="
# 補助セッション等で実体トランスクリプトが1つも無い枠。開始15分超→⏸、15分未満→維持（行削除はしない・⏸止まり）
GHOST_OLD=$(date -v-16M +%H:%M)   # 16分前開始（>15分）→掃除対象
GHOST_NEW=$(date -v-5M +%H:%M)    # 5分前開始（<15分）→維持
"$BOARD" add --key gho5t001 --repo GhostRepo --who "claude/?" --time "$GHOST_OLD"
"$BOARD" update --key gho5t001 --goal "実体なし枠(古)" --now "放置"
"$BOARD" add --key gho5t002 --repo GhostRepo --who "claude/?" --time "$GHOST_NEW"
"$BOARD" update --key gho5t002 --goal "実体なし枠(新)" --now "起動直後"
# 実体ファイルは作らない（探索ルートに gho5t001/gho5t002 を含む .jsonl は無い）
"$BOARD" reconcile
[ "$("$BOARD" check --key gho5t001)" = "wait" ]; ok "実体なし15分超→⏸(幽霊枠掃除)" test $? -eq 0
[ "$("$BOARD" check --key gho5t002)" = "run" ];  ok "実体なし15分未満→維持" test $? -eq 0
ok "幽霊枠は行削除でなく⏸止まり（行は残る）" bash -c "grep -qF 's:gho5t001' '$DAILY'"

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
