#!/bin/bash
# session-board 再設計のテスト（env差し替え・実ボードに触れない）
# パスはスクリプト位置から相対解決（worktree でもそのまま動く）
set -u
SB="$(cd "$(dirname "$0")/.." && pwd)"
CL="$(cd "$(dirname "$0")/../../../claude" && pwd)"
CX="$(cd "$(dirname "$0")/../../../codex" && pwd)"
SP="$(cd "$(dirname "$0")" && pwd)/sbtest"
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-01" SESSION_BOARD_TX_ROOTS="$SP/tx"
BOARD="$SB/board.py"
DAILY="$SP/goal/2099/01/2099-01-01.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }
grepq(){ grep -qF -- "$1" "$DAILY"; }

echo "=== 1. add: 新形式の枠行 ==="
"$BOARD" add --key aaaa0001 --repo RepoA --who "claude/?" --time 14:00
ok "add新形式行" grepq "- 🟢 14:00 | ? | 今:? | RepoA | その他 | claude/? <!-- s:aaaa0001 -->"

echo "=== 2. update: goal/now/type/model 反映・時刻不変 ==="
"$BOARD" update --key aaaa0001 --type 実装 --goal "ボード再設計" --now "board.py改修" --model fable5
ok "update反映" grepq "- 🟢 14:00 | ボード再設計 | 今:board.py改修 | RepoA | 実装 | claude/fable5 <!-- s:aaaa0001 -->"

echo "=== 3. add冪等: 既存行を上書きしない ==="
"$BOARD" add --key aaaa0001 --repo RepoX --who "codex/?"
ok "add冪等(内容不変)" grepq "| ボード再設計 | 今:board.py改修 | RepoA | 実装 | claude/fable5 <!-- s:aaaa0001 -->"

echo "=== 4. show / goals / check ==="
SHOW="$("$BOARD" show --key aaaa0001)"
[ "$SHOW" = "$(printf 'run\tボード再設計\tboard.py改修\t実装\tRepoA\tclaude/fable5')" ]; ok "show出力" test $? -eq 0
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
ok "旧→新形式へ移行" grepq "- 🟢 09:15 | 旧形式の要約テキスト | 今:? | OldRepo | 計画 | ? <!-- s:eeee0005 -->"
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

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
