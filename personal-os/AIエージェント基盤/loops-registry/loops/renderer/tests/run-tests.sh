#!/usr/bin/env bash
# renderer / tests / run-tests.sh — fixtureベースのテストスイート。
# 実デイリー（~/Private/personal-os/my-brain/ゴール/デイリー/）には一切書き込まない。
# 各テストは独立の mktemp -d ワークコピー上で実行し、env上書きだけで完結させる。
# 終了コードで全体の合否を表す（0=全PASS／非0=1件以上FAIL）。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_DIR="$(cd "$TESTS_DIR/.." && pwd)"
LOOPS_DIR="$(cd "$RENDERER_DIR/.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"

pass_count=0
fail_count=0
fail_names=()
workdirs=()

cleanup_all() {
  local d
  for d in "${workdirs[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
trap cleanup_all EXIT

# render.sh は末尾で notion-push.sh を呼ぶ（本patchで新規追加）。実キーチェーン・実API・実stateに
# 一切触れないよう、全テスト共通で固定stubにする（NOTION_SECURITY_CMDが実キーチェーンにヒットしない
# 環境でのみ動く暗黙依存を避けるため。人間がnotion-personal-osキーチェーン項目を登録した後も
# このテストスイートは実API/実トークンに触らないことを保証する）。
notion_security_fail_stub="$(mktemp "${TMPDIR:-/tmp}/notion-push-test-security-fail.XXXXXX")"
cat > "$notion_security_fail_stub" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$notion_security_fail_stub"
notion_push_test_state_dir="$(mktemp -d "${TMPDIR:-/tmp}/notion-push-test-state.XXXXXX")"
workdirs+=("$notion_security_fail_stub" "$notion_push_test_state_dir")
export NOTION_SECURITY_CMD="$notion_security_fail_stub"
export NOTION_CURL_CMD="false"
export NOTION_PUSH_STATE_DIR="$notion_push_test_state_dir"

# --- ヘルパ ---

# renderer/scripts と daily-digest/scripts を相対構造を保ったまま独立workdirへコピーする。
new_workdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/renderer-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$RENDERER_DIR/templates" "$d/loops-registry/loops/renderer/templates"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

render_bin() { printf '%s/loops-registry/loops/renderer/scripts/render.sh' "$1"; }
debounced_bin() { printf '%s/loops-registry/loops/renderer/scripts/render-debounced.sh' "$1"; }

# マーカー内側（goal/align/done/log/carry/progress）をすべて空にした版を作る。
# 2つの版を比較すればマーカー外（人間行）の差分だけが残る。
strip_markers() {
  local src="$1" out="$2" workdir="$3"
  local set_marker="$workdir/loops-registry/loops/daily-digest/scripts/set-marker-block.sh"
  local empty key
  empty="$(mktemp "${TMPDIR:-/tmp}/renderer-test-empty.XXXXXX")"
  : > "$empty"
  cp "$src" "$out"
  for key in goal align done log carry progress tomorrow-carry board-now board-wait board-plans digest; do
    "$set_marker" "$out" "$key" "$empty" >/dev/null 2>&1 || true
  done
  rm -f "$empty"
}

run_test() {
  local name="$1"
  echo "=== $name ==="
  if "$name"; then
    echo "PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $name"
    fail_count=$((fail_count + 1))
    fail_names+=("$name")
  fi
  echo
}

# orca worktree ps --json の既定スタブ（0件の正常応答）。実orca CLIを叩かない・決定的。
NOOP_ORCA_PS_CMD='printf %s "{\"result\":{\"totalCount\":0,\"worktrees\":[]}}"'

# 共通env（GOAL_BASE等）をセットし、年間計画fixtureを配置する。呼び出し側のシェルで export する。
# AREAS_BASEは空の隔離ディレクトリ、ORCA_PS_CMDは既定スタブにする
# （実HOME配下のareas走査・実orca CLI呼び出しを防ぐ。実デイリー・実HOME書込禁止の一環）。
setup_common_env() {
  local workdir="$1"
  GOAL_BASE="$workdir/data/goal-base"
  AIJOBS_BASE="$workdir/data/ai-jobs"
  CLAUDE_PROJECTS_BASE="$workdir/data/claude-projects"
  CODEX_INDEX="$workdir/data/codex/session_index.jsonl"
  CODEX_SESSIONS_BASE="$workdir/data/codex/sessions"
  DAILY_TEMPLATE="$RENDERER_DIR/templates/デイリー.md"
  AREAS_BASE="$workdir/data/areas-base"
  ORCA_PS_CMD="$NOOP_ORCA_PS_CMD"
  export GOAL_BASE AIJOBS_BASE CLAUDE_PROJECTS_BASE CODEX_INDEX CODEX_SESSIONS_BASE DAILY_TEMPLATE AREAS_BASE ORCA_PS_CMD
  mkdir -p "$GOAL_BASE/年間計画" "$AREAS_BASE"
  cp "$FIXTURES_DIR/yearly-plan-2026.md" "$GOAL_BASE/年間計画/2026.md"
}

# renderer/board向けfixture(orca ps JSON・areas計画tree)を用意する。setup_common_env呼び出し後に使う。
# 紐付き済みレーン(board-live-v1)は実在するgitリポジトリを指す（basename=board-live-v1固定）。
# サブディレクトリcwdの陰性テスト(t17)がこの実パス配下にコミットを作れるようにするため。
# 呼び出し後、非localの $BOARD_LIVE_V1_PATH でこのパスを参照できる。
setup_board_fixtures() {
  local workdir="$1"
  local orca_json="$workdir/data/orca-ps.json"
  mkdir -p "$(dirname "$orca_json")"

  BOARD_LIVE_V1_PATH="$workdir/data/worktrees/board-live-v1"
  mkdir -p "$BOARD_LIVE_V1_PATH"
  (
    cd "$BOARD_LIVE_V1_PATH"
    git init -q
    git config user.email board-live-v1@t.example
    git config user.name "renderer-test"
    : > .gitkeep
    git add .gitkeep
    git commit -qm "board-live-v1: init"
  )

  cat > "$orca_json" <<EOF
{
  "id": "fixture",
  "ok": true,
  "result": {
    "totalCount": 2,
    "truncated": false,
    "worktrees": [
      {
        "path": "$BOARD_LIVE_V1_PATH",
        "displayName": "統合設計子04a:ボード実況",
        "branch": "refs/heads/nextlevelkitamura-alt/board-live-v1",
        "status": "in-progress",
        "agents": [
          {
            "agentType": "claude",
            "state": "working",
            "lastAssistantMessage": "設計を進めています。\n段階: 人間確認待ち"
          }
        ]
      },
      {
        "path": "/fake/worktrees/unknown-repo",
        "displayName": "適当な作業用ワークツリー",
        "branch": "refs/heads/scratch",
        "status": "in-progress",
        "agents": [
          {
            "agentType": "codex",
            "state": "done",
            "lastAssistantMessage": "調査結果です。特に問題ありませんでした。"
          }
        ]
      }
    ]
  }
}
EOF
  ORCA_PS_CMD="cat '$orca_json'"
  export ORCA_PS_CMD

  local ai_program_dir="$AREAS_BASE/ai運用/plans/active/2026-01-01-テスト統合プログラム"
  mkdir -p "$ai_program_dir"
  cat > "$ai_program_dir/program.md" <<'EOF'
分類: 横断 ／ 種別: 統合整理 ／ 形態: program ／ 優先: ◎

# テスト統合プログラム

## 目的

テスト用。

## 子計画マップ

01  テスト子計画A … 完了
    次: なし
    場所: plans/01 ／ 依存: ―
02  テスト子計画B … 計画
    次: 着手待ち
    場所: plans/02 ／ 依存: 01

## 完了条件（レビュー項目）

- [ ] ダミー
EOF

  local work_plan_dir="$AREAS_BASE/work/plans/active/2026-01-01-テスト単発計画"
  mkdir -p "$work_plan_dir"
  cat > "$work_plan_dir/plan.md" <<'EOF'
分類: repo ／ 種別: 既存改善

# テスト単発計画

## 目的

テスト用。

## 現状

なし。

## 方針

なし。

## 完了条件（レビュー項目）

- [ ] ダミー
EOF
}

# ============================================================
# t1: 当日ファイル自動生成（8見出し＋マーカーが揃う・既存ファイルは上書きしない）
# ============================================================
t1_daily_auto_generate() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  [ ! -f "$daily" ] || { echo "前提崩れ: 既にファイルがある"; return 1; }
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "デイリーが生成されていない"; return 1; }

  expected='## 逆算
## 今日のTODO
## 依頼インボックス
## 今やっていること
## 待ち
## 計画ボード
## 今日のダイジェスト
## 今日終わったこと
## ログ
## 明日へ'
  actual="$(grep -E '^## ' "$daily")"
  [ "$actual" = "$expected" ] || { echo "見出し10個・この順が不一致:"; echo "$actual"; return 1; }

  local key
  for key in goal align done log; do
    grep -qE "^<!-- auto:${key}:begin" "$daily" || { echo "auto:${key} begin無し"; return 1; }
    grep -qE "^<!-- auto:${key}:end -->" "$daily" || { echo "auto:${key} end無し"; return 1; }
  done

  # 既存ファイルがあれば上書きしない（末尾センチネルが生き残るか）
  echo "SENTINEL-T1" >> "$daily"
  "$render" 2026-07-02 >/dev/null 2>&1
  tail -1 "$daily" | grep -q "SENTINEL-T1" || { echo "既存ファイルが上書きされた（テンプレから再生成された）"; return 1; }

  return 0
)

# ============================================================
# t2: 人間行不可侵（マーカー外の人間行は1文字も変わらない）
# ============================================================
t2_human_lines_untouched() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  # マーカー外の人間欄・注記欄に手書き内容を注入する。
  # 今やっていること／待ち／計画ボードはauto:board-*マーカーの区画なので、注入位置は
  # 見出し直後（=マーカー内側）ではなく対応するend-marker行の直後（=マーカー外側）にする。
  awk '
    /^## 今日のTODO/         { print; getline; print "- [ ] 買い物に行く（人間TODO）"; next }
    /^## 依頼インボックス/   { print; getline; print "- 依頼A: 見積を確認して欲しい（人間インボックス）"; next }
    /^<!-- auto:board-now:end/   { print; print "追加メモ: 今やっていることの自由記述テスト"; next }
    /^<!-- auto:board-wait:end/  { print; print "追加メモ: 待ちの自由記述テスト"; next }
    /^<!-- auto:board-plans:end/ { print; print "追加メモ: 計画ボードの自由記述テスト"; next }
    /^## 今日終わったこと/   { print; getline; print "- 機能Xの実装が完了した（人間実績）"; next }
    { print }
  ' "$daily" > "$daily.tmp" && mv "$daily.tmp" "$daily"

  before="$workdir/before-stripped.md"
  strip_markers "$daily" "$before" "$workdir"

  "$render" 2026-07-02 >/dev/null 2>&1

  after="$workdir/after-stripped.md"
  strip_markers "$daily" "$after" "$workdir"

  diff -q "$before" "$after" >/dev/null || { echo "人間行（マーカー外）が変化した:"; diff "$before" "$after" || true; return 1; }

  # 注入した人間行そのものも実ファイルに残っているか（消えていないか）を直接確認する。
  grep -qF "買い物に行く（人間TODO）" "$daily" || { echo "人間TODO行が消えた"; return 1; }
  grep -qF "依頼A: 見積を確認して欲しい" "$daily" || { echo "人間インボックス行が消えた"; return 1; }
  grep -qF "機能Xの実装が完了した（人間実績）" "$daily" || { echo "人間実績行が消えた"; return 1; }
  grep -qF "追加メモ: 今やっていることの自由記述テスト" "$daily" || { echo "今やっていることの自由記述が消えた"; return 1; }
  grep -qF "追加メモ: 待ちの自由記述テスト" "$daily" || { echo "待ちの自由記述が消えた"; return 1; }
  grep -qF "追加メモ: 計画ボードの自由記述テスト" "$daily" || { echo "計画ボードの自由記述が消えた"; return 1; }

  return 0
)

# ============================================================
# t3: 冪等（Codex＋Claude transcript＋一時git repo＋done cardで2回連続render→差分ゼロ）
# ============================================================
t3_idempotency() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$AIJOBS_BASE/done" "$CLAUDE_PROJECTS_BASE/proj1" "$CODEX_SESSIONS_BASE/2026/07/02"

  gitrepo="$workdir/data/gitrepo"
  mkdir -p "$gitrepo"
  (
    cd "$gitrepo"
    git init -q
    git config user.email t@t.example
    git config user.name "renderer-test"
    echo a > a.txt && git add a.txt && git commit -qm "最初のコミット"
    echo b > b.txt && git add b.txt && git commit -qm "2番目のコミット"
  )

  cat > "$CLAUDE_PROJECTS_BASE/proj1/sess-idem-1.jsonl" <<EOF
{"timestamp":"2026-07-02T01:00:00Z","cwd":"$gitrepo"}
{"timestamp":"2026-07-02T01:05:00Z"}
EOF
  touch -t 202607021305 "$CLAUDE_PROJECTS_BASE/proj1/sess-idem-1.jsonl"

  cat > "$CODEX_INDEX" <<'EOF'
{"id":"codex-idem-1","thread_name":"冪等テスト用スレッド","updated_at":"2026-07-02T02:30:00.000000Z"}
EOF
  cat > "$CODEX_SESSIONS_BASE/2026/07/02/rollout-2026-07-02T02-30-00-codex-idem-1.jsonl" <<'EOF'
{"type":"session_meta","payload":{"cwd":"/tmp/some-codex-project","git":{"repository_url":"https://example.com/some-codex-project.git"}}}
EOF

  cat > "$AIJOBS_BASE/done/card-idem.md" <<'EOF'
担当: claude
出所: ready/card-idem.md
EOF
  touch -t 202607021200 "$AIJOBS_BASE/done/card-idem.md"

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/run1.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/run2.md"

  diff -q "$workdir/run1.md" "$workdir/run2.md" >/dev/null || { echo "2回連続実行で差分が出た（冪等でない）:"; diff "$workdir/run1.md" "$workdir/run2.md" || true; return 1; }

  grep -q "codex-idem-1" "$daily" || { echo "Codexセッションが反映されていない（テスト自体が無意味）"; return 1; }
  grep -q "sess-idem-1" "$daily" || { echo "Claudeセッションが反映されていない（テスト自体が無意味）"; return 1; }
  grep -q "card-idem.md" "$daily" || { echo "doneカードが反映されていない（テスト自体が無意味）"; return 1; }

  return 0
)

# ============================================================
# t4: 旧形式互換（2026-07-01実物のコピー・無いマーカーはskip警告のみ・人間行不変・exit 0）
# ============================================================
t4_legacy_compat() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$GOAL_BASE/デイリー/2026/07"
  render="$(render_bin "$workdir")"

  # --- サブケース1: 実物そのままのコピー（4マーカーとも存在） ---
  daily1="$GOAL_BASE/デイリー/2026/07/2026-07-01.md"
  cp "$FIXTURES_DIR/daily-2026-07-01-legacy.md" "$daily1"
  before1="$workdir/before1-stripped.md"
  strip_markers "$daily1" "$before1" "$workdir"

  out1="$("$render" 2026-07-01 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "sub1: exit非0 ($rc1):"; echo "$out1"; return 1; }

  after1="$workdir/after1-stripped.md"
  strip_markers "$daily1" "$after1" "$workdir"
  diff -q "$before1" "$after1" >/dev/null || { echo "sub1: 人間行が変化した:"; diff "$before1" "$after1" || true; return 1; }

  grep -q "auto:carry:begin" "$daily1" || { echo "sub1: auto:carryマーカーが消えた（renderer対象外のはず）"; return 1; }
  grep -q "auto:progress:begin" "$daily1" || { echo "sub1: auto:progressマーカーが消えた（renderer対象外のはず）"; return 1; }

  # --- サブケース2: auto:alignマーカーを欠損させた版でskip経路（警告のみ・exit 0）を確認 ---
  daily2="$GOAL_BASE/デイリー/2026/07/2026-07-08.md"
  cp "$FIXTURES_DIR/daily-2026-07-01-legacy.md" "$daily2"
  sed -i '' '/<!-- auto:align:begin/,/<!-- auto:align:end -->/d' "$daily2"

  before2="$workdir/before2-stripped.md"
  strip_markers "$daily2" "$before2" "$workdir"

  out2="$("$render" 2026-07-08 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "sub2: exit非0 ($rc2):"; echo "$out2"; return 1; }
  printf '%s\n' "$out2" | grep -q "警告.*auto:align.*スキップ" || { echo "sub2: skip警告が出ていない。出力: $out2"; return 1; }

  after2="$workdir/after2-stripped.md"
  strip_markers "$daily2" "$after2" "$workdir"
  diff -q "$before2" "$after2" >/dev/null || { echo "sub2: 人間行が変化した:"; diff "$before2" "$after2" || true; return 1; }

  grep -q "auto:align:begin" "$daily2" && { echo "sub2: 無いはずのauto:alignマーカーが足された"; return 1; }

  return 0
)

# ============================================================
# t5: Codex当日判定（UTC→JST境界・壊れJSON行混在でも他行は処理される）
# ============================================================
t5_codex_jst_boundary() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$(dirname "$CODEX_INDEX")" "$CODEX_SESSIONS_BASE"

  cat > "$CODEX_INDEX" <<'EOF'
{"id":"in-boundary-start","thread_name":"境界開始ぴったり","updated_at":"2026-07-01T15:00:00.000000Z"}
{"id":"out-before-boundary","thread_name":"境界直前","updated_at":"2026-07-01T14:59:59.000000Z"}
{"id":"in-midday","thread_name":"当日昼","updated_at":"2026-07-01T20:00:00.000000Z"}
{broken json that does not parse at all
{"id":"out-next-day","thread_name":"翌日境界","updated_at":"2026-07-02T15:00:00.000000Z"}
{"missing":"id field only"}
EOF

  codex_pull="$workdir/loops-registry/loops/renderer/scripts/codex-pull.sh"
  out="$("$codex_pull" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "codex-pull.sh 異常終了 ($rc):"; echo "$out"; return 1; }

  echo "$out" | grep -q "in-boundary-start" || { echo "境界開始ぴったり（前日15:00Z）が含まれない: $out"; return 1; }
  echo "$out" | grep -q "in-midday" || { echo "当日昼が含まれない: $out"; return 1; }
  echo "$out" | grep -q "out-before-boundary" && { echo "境界直前（前日14:59:59Z＝前日JST）が誤って含まれた: $out"; return 1; }
  echo "$out" | grep -q "out-next-day" && { echo "翌日境界（当日15:00Z＝翌日JST）が誤って含まれた: $out"; return 1; }

  return 0
)

# ============================================================
# t6: auto:carry / auto:progress がテンプレ・生成物のどこにも無い
# ============================================================
t6_no_carry_progress() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  grep -q "auto:carry" "$DAILY_TEMPLATE" && { echo "テンプレにauto:carryがある"; return 1; }
  grep -q "auto:progress" "$DAILY_TEMPLATE" && { echo "テンプレにauto:progressがある"; return 1; }
  grep -q "auto:carry" "$daily" && { echo "生成物にauto:carryがある"; return 1; }
  grep -q "auto:progress" "$daily" && { echo "生成物にauto:progressがある"; return 1; }

  return 0
)

# ============================================================
# t7: debounce（3連打→renderは1〜2回に合流・呼び出しは即時return）
# ============================================================
t7_debounce() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  RENDERER_STATE_DIR="$workdir/data/renderer-state"
  RENDERER_DEBOUNCE_SECONDS=1
  export RENDERER_STATE_DIR RENDERER_DEBOUNCE_SECONDS
  debounced="$(debounced_bin "$workdir")"

  t0=$(date +%s)
  "$debounced" 2026-07-02
  "$debounced" 2026-07-02
  sleep 0.3
  "$debounced" 2026-07-02
  t1=$(date +%s)
  elapsed=$((t1 - t0))
  [ "$elapsed" -le 2 ] || { echo "呼び出しがブロックした（${elapsed}秒。即returnのはず）"; return 1; }

  sleep 6

  [ -f "$RENDERER_STATE_DIR/invocations.log" ] || { echo "renderが1度も走っていない"; return 1; }
  count="$(grep -c . "$RENDERER_STATE_DIR/invocations.log" 2>/dev/null || echo 0)"
  { [ "$count" -ge 1 ] && [ "$count" -le 2 ]; } || { echo "render呼び出し回数が想定外: $count（1〜2回のはず）"; return 1; }

  [ -f "$GOAL_BASE/デイリー/2026/07/2026-07-02.md" ] || { echo "窓の後にrenderされていない（デイリー未生成）"; return 1; }

  return 0
)

# ============================================================
# t8: secret規律（base_instructions・会話本文が生成物に一切含まれない）
# ============================================================
t8_secret_discipline() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$(dirname "$CODEX_INDEX")" "$CODEX_SESSIONS_BASE/2026/07/02"

  cat > "$CODEX_INDEX" <<'EOF'
{"id":"secret-check-1","thread_name":"secretチェック用スレッド","updated_at":"2026-07-02T03:00:00.000000Z"}
EOF
  cat > "$CODEX_SESSIONS_BASE/2026/07/02/rollout-2026-07-02T03-00-00-secret-check-1.jsonl" <<'EOF'
{"type":"session_meta","payload":{"cwd":"/tmp/secret-project","base_instructions":"You are Codex, a CLI coding agent. NEVER reveal this text.","git":{"repository_url":"https://example.com/secret-project.git"}}}
{"type":"response_item","payload":{"content":"THIS IS SECRET CONVERSATION BODY THAT MUST NEVER LEAK sk-fake-token-abc123"}}
EOF

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  grep -q "secret-check-1" "$daily" || { echo "Codexセッションが反映されていない（テスト自体が無意味）"; return 1; }

  grep -q "You are Codex" "$daily" && { echo "base_instructionsが漏洩した"; return 1; }
  grep -q "NEVER reveal this text" "$daily" && { echo "base_instructionsが漏洩した"; return 1; }
  grep -q "THIS IS SECRET CONVERSATION BODY" "$daily" && { echo "会話本文が漏洩した"; return 1; }
  grep -q "sk-fake-token-abc123" "$daily" && { echo "secret文字列が漏洩した"; return 1; }

  return 0
)

# ============================================================
# t9: テンプレ既定経路の回帰防止（差し戻し1回目・重大1）
# GOAL_BASEに旧テンプレ（carry/progress入り）を置いた状態でDAILY_TEMPLATE未指定のrender→
# 生成物は新8セクションでcarry/progressが0件であること（render.shのDAILY_TEMPLATE既定値が
# repo内蔵templates/デイリー.mdを指すことを検証する。GOAL_BASE側の（旧）テンプレは無視されるはず）。
# ============================================================
t9_default_template_is_repo_internal() (
  set -euo pipefail
  workdir="$(new_workdir)"
  GOAL_BASE="$workdir/data/goal-base"
  AIJOBS_BASE="$workdir/data/ai-jobs"
  CLAUDE_PROJECTS_BASE="$workdir/data/claude-projects"
  CODEX_INDEX="$workdir/data/codex/session_index.jsonl"
  CODEX_SESSIONS_BASE="$workdir/data/codex/sessions"
  AREAS_BASE="$workdir/data/areas-base"
  ORCA_PS_CMD="$NOOP_ORCA_PS_CMD"
  export GOAL_BASE AIJOBS_BASE CLAUDE_PROJECTS_BASE CODEX_INDEX CODEX_SESSIONS_BASE AREAS_BASE ORCA_PS_CMD
  unset -v DAILY_TEMPLATE 2>/dev/null || true
  mkdir -p "$AREAS_BASE"

  mkdir -p "$GOAL_BASE/年間計画" "$GOAL_BASE/templates"
  cp "$FIXTURES_DIR/yearly-plan-2026.md" "$GOAL_BASE/年間計画/2026.md"
  # GOAL_BASE側にわざと「旧テンプレ（auto:carry/progress入り）」を置く。
  # DAILY_TEMPLATE を上書きしなければ、renderer はこれを無視して repo 内蔵の新テンプレを使うはず。
  cp "$FIXTURES_DIR/legacy-template-with-carry-progress.md" "$GOAL_BASE/templates/デイリー.md"

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  [ ! -f "$daily" ] || { echo "前提崩れ: 既にファイルがある"; return 1; }

  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "デイリーが生成されていない"; return 1; }

  expected='## 逆算
## 今日のTODO
## 依頼インボックス
## 今やっていること
## 待ち
## 計画ボード
## 今日のダイジェスト
## 今日終わったこと
## ログ
## 明日へ'
  actual="$(grep -E '^## ' "$daily")"
  [ "$actual" = "$expected" ] || { echo "見出しが新10セクションでない（GOAL_BASE側の旧テンプレが使われた疑い）:"; echo "$actual"; return 1; }

  grep -q "auto:carry" "$daily" && { echo "GOAL_BASE側の旧テンプレ由来のauto:carryが混入した"; return 1; }
  grep -q "auto:progress" "$daily" && { echo "GOAL_BASE側の旧テンプレ由来のauto:progressが混入した"; return 1; }

  return 0
)

# ============================================================
# t10: auto:log マーカー欠落時のskip意味論（差し戻し1回目・重大2）
# 旧形式ファイルからauto:logマーカーを丸ごと削った状態でrender→exit 0・ファイル不変（警告のみ）。
# 修正前は claude-backfill.sh が `set -e` 下でexit 3のまま落ち、render.shがexit 1で終わっていた。
# ============================================================
t10_missing_log_marker_skips_cleanly() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$GOAL_BASE/デイリー/2026/07"

  daily="$GOAL_BASE/デイリー/2026/07/2026-07-01.md"
  cp "$FIXTURES_DIR/daily-2026-07-01-legacy.md" "$daily"
  sed -i '' '/<!-- auto:log:begin/,/<!-- auto:log:end -->/d' "$daily"

  before="$workdir/before-stripped.md"
  strip_markers "$daily" "$before" "$workdir"

  render="$(render_bin "$workdir")"
  out="$("$render" 2026-07-01 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc)（Critical2再発の疑い）:"; echo "$out"; return 1; }

  printf '%s\n' "$out" | grep -q "警告.*auto:log.*スキップ" || { echo "auto:logのskip警告が出ていない。出力: $out"; return 1; }

  after="$workdir/after-stripped.md"
  strip_markers "$daily" "$after" "$workdir"
  diff -q "$before" "$after" >/dev/null || { echo "人間行が変化した:"; diff "$before" "$after" || true; return 1; }

  grep -q "auto:log:begin" "$daily" && { echo "無いはずのauto:logマーカーが足された"; return 1; }

  return 0
)

# ============================================================
# t11: debounce中のイベント取り逃し防止（差し戻し1回目・重大3）
# stub render（実行に1秒かかる）で、render実行中に2発目のイベントを入れる→
# render呼び出しが合計2回になること。
# ============================================================
t11_debounce_no_lost_event_during_render() (
  set -euo pipefail
  workdir="$(new_workdir)"
  mkdir -p "$workdir/data"
  calls_log="$workdir/data/calls.log"
  : > "$calls_log"

  # render.sh をstub化し、debounceの合流/取り逃しロジックだけを切り出して検証する。
  render_sh="$workdir/loops-registry/loops/renderer/scripts/render.sh"
  cat > "$render_sh" <<EOF
#!/usr/bin/env bash
echo "call \$(date +%s)" >> "$calls_log"
sleep 1
EOF
  chmod +x "$render_sh"

  RENDERER_STATE_DIR="$workdir/data/renderer-state"
  RENDERER_DEBOUNCE_SECONDS=2
  export RENDERER_STATE_DIR RENDERER_DEBOUNCE_SECONDS
  debounced="$(debounced_bin "$workdir")"

  "$debounced" 2026-07-02
  sleep 2.5
  # ↑ここまでで1発目のrenderがちょうど走り始めている頃合い（窓2秒＋起動オーバーヘッド）。
  "$debounced" 2026-07-02
  # ↑render実行中（1秒間）に2発目のイベントを打ち込む。

  sleep 7

  count="$(grep -c '^call ' "$calls_log" 2>/dev/null || echo 0)"
  [ "$count" -eq 2 ] || { echo "render呼び出し回数が2でない（取り逃しの疑い）: $count"; cat "$calls_log"; return 1; }

  return 0
)

# ============================================================
# t12: codex-pull.sh の性能・正確性（差し戻し2回目・実環境実走で検出のバグ1）
# 実環境 ~/.codex/session_index.jsonl（1185行）で1回のrenderが数分級だった。
# 1000行級fixture（当日分数件＋過去分大量＋壊れ行混在＋重複id）でcodex-pull.shが2秒以内に完了し、
# 抽出結果（当日分のみ・重複排除=最新採用・時刻昇順）も正しいことを検証する。
# ============================================================
t12_codex_pull_performance_and_correctness() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$(dirname "$CODEX_INDEX")" "$CODEX_SESSIONS_BASE"

  # 過去分1000行（対象日2026-07-02とは重ならない2020〜2022年台）をawk単発で生成する
  # （fixture生成自体を行ごとのプロセス起動で遅くしないため）。
  awk 'BEGIN {
    for (i = 1; i <= 1000; i++) {
      y = 2020 + int(i / 365)
      d = i % 365
      m = int(d / 30) + 1; if (m > 12) m = 12
      dom = (d % 28) + 1
      printf "{\"id\":\"bulk-%04d\",\"thread_name\":\"バルクデータ%04d\",\"updated_at\":\"%04d-%02d-%02dT10:00:00.000000Z\"}\n", i, i, y, m, dom
    }
  }' > "$CODEX_INDEX"

  {
    echo '{broken json line without closing brace'
    echo '{"missing":"updated_at field only","id":"no-updated-at"}'
    echo '{"id":"today-1","thread_name":"当日分1","updated_at":"2026-07-01T15:00:00.000000Z"}'
    echo '{"id":"today-2","thread_name":"当日分2旧・採用されないはず","updated_at":"2026-07-01T20:00:00.000000Z"}'
    echo '{"id":"today-2","thread_name":"当日分2新・採用されるはず","updated_at":"2026-07-01T22:00:00.000000Z"}'
    echo '{"id":"today-3","thread_name":"当日分3","updated_at":"2026-07-02T10:00:00.000000Z"}'
    echo '{"id":"out-of-range","thread_name":"翌日分・対象外","updated_at":"2026-07-02T15:00:00.000000Z"}'
  } >> "$CODEX_INDEX"

  line_count="$(wc -l < "$CODEX_INDEX" | tr -d ' ')"
  [ "$line_count" -ge 1000 ] || { echo "fixtureが1000行未満: $line_count"; return 1; }

  codex_pull="$workdir/loops-registry/loops/renderer/scripts/codex-pull.sh"

  t0="$(date +%s.%N)"
  out="$("$codex_pull" 2026-07-02 2>&1)"; rc=$?
  t1="$(date +%s.%N)"
  elapsed="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')"

  [ "$rc" -eq 0 ] || { echo "codex-pull.sh 異常終了 ($rc):"; echo "$out"; return 1; }
  awk -v e="$elapsed" 'BEGIN{exit !(e <= 2.0)}' || { echo "性能要件未達（${elapsed}秒。2秒以内のはず・${line_count}行）"; return 1; }

  echo "$out" | grep -q "session=today-1\$" || { echo "today-1が含まれない: $out"; return 1; }
  echo "$out" | grep -q "当日分2新" || { echo "today-2の重複排除で新しい方が採用されていない: $out"; return 1; }
  echo "$out" | grep -q "当日分2旧" && { echo "today-2の古い方が残っている（重複排除失敗）: $out"; return 1; }
  echo "$out" | grep -q "session=today-3\$" || { echo "today-3が含まれない: $out"; return 1; }
  echo "$out" | grep -q "out-of-range" && { echo "翌日分(JST境界外)が誤って含まれた: $out"; return 1; }
  echo "$out" | grep -q "bulk-" && { echo "過去分(bulk fixture)が誤って含まれた: $out"; return 1; }

  order="$(echo "$out" | grep -oE 'session=[a-z0-9-]+' | sed 's/^session=//')"
  expected_order='today-1
today-2
today-3'
  [ "$order" = "$expected_order" ] || { echo "時刻昇順になっていない: [$order]"; return 1; }

  return 0
)

# ============================================================
# t13: GOAL_BASE未exportの実環境を再現→auto:goalが正しく転記される（差し戻し2回目・バグ2根本原因）
# _paths.shがexportしていなかったため、hook/launchd起動でGOAL_BASEが環境に無いと
# build-goal.shが『GOAL_BASE required』で即死し、auto:goalが空置換されていた。
# ============================================================
t13_goal_base_not_exported_reproduces_and_fixed() (
  set -euo pipefail
  workdir="$(new_workdir)"
  fake_home="$workdir/data/fake-home"
  mkdir -p "$fake_home/Private/personal-os/my-brain/ゴール/年間計画" \
           "$fake_home/Private/personal-os/my-brain/ゴール/templates"
  cat > "$fake_home/Private/personal-os/my-brain/ゴール/年間計画/2026.md" <<'EOF'
# 2026 年間計画
## 領域別の目標（各3つ）
### work
- t13検証用の的
EOF
  # my-brain側に旧テンプレが残っていても（人間ゲート未実施の現状再現）rendererはrepo内蔵テンプレを使う。
  cp "$FIXTURES_DIR/legacy-template-with-carry-progress.md" \
     "$fake_home/Private/personal-os/my-brain/ゴール/templates/デイリー.md"

  render="$(render_bin "$workdir")"
  daily="$fake_home/Private/personal-os/my-brain/ゴール/デイリー/2026/07/2026-07-02.md"

  # GOAL_BASE/AIJOBS_BASE等を一切exportせず、HOMEだけ指定して実行（実環境=hook/launchd起動の再現）。
  # ORCA_PS_CMDだけは明示的にスタブへ差し替える（未指定だと実orca CLIを叩いてしまうため）。
  # AREAS_BASEはあえて未指定のまま（未export時の既定値がfake_home配下に安全にフォールバックし、
  # 実HOMEのareasを走査しないことも本テストの検証範囲に含める）。
  out="$(env -u GOAL_BASE -u AIJOBS_BASE -u CLAUDE_PROJECTS_BASE -u CODEX_INDEX -u CODEX_SESSIONS_BASE -u DAILY_TEMPLATE \
    ORCA_PS_CMD="$NOOP_ORCA_PS_CMD" \
    HOME="$fake_home" "$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc):"; echo "$out"; return 1; }
  [ -f "$daily" ] || { echo "デイリー未生成: $daily"; return 1; }

  echo "$out" | grep -q "GOAL_BASE required" && { echo "GOAL_BASE未export起因のエラーが再発した: $out"; return 1; }

  grep -q "t13検証用の的" "$daily" || {
    echo "auto:goalに年間計画の的が転記されていない（env伝播バグの疑い）:"
    sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily"
    return 1
  }

  return 0
)

# ============================================================
# t14: builder失敗時の空置換防御（差し戻し2回目・バグ2の防御第2段）
# build-goal.shをstubで失敗させても、auto:goalの既存内容が保持され、警告が出て、
# render自体は継続し他マーカー（auto:done/align）は正常更新されることを検証する。
# ============================================================
t14_builder_failure_preserves_marker_content() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  # 1回目は正常render。auto:goalに実コンテンツ（保持されるべき「既存内容」）を作る。
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }
  grep -q "ai運用" "$daily" || { echo "前提崩れ: auto:goalに実コンテンツが無い"; return 1; }
  before_goal="$workdir/before-goal.txt"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$before_goal"

  # build-goal.sh をこのworkdir内だけstub化し、人為的に失敗させる
  # （実際の障害原因は問わない。render.sh側の防御ロジックだけを切り出して検証する）。
  build_goal_sh="$workdir/loops-registry/loops/renderer/scripts/build-goal.sh"
  cat > "$build_goal_sh" <<'EOF'
#!/usr/bin/env bash
echo "stub: 人為的な失敗" >&2
exit 1
EOF
  chmod +x "$build_goal_sh"

  out="$("$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "builder失敗時にexitが0になった（失敗が握りつぶされている）"; return 1; }

  printf '%s\n' "$out" | grep -q "警告.*build-goal.sh.*失敗.*auto:goal" || { echo "builder失敗の警告が出ていない。出力: $out"; return 1; }

  after_goal="$workdir/after-goal.txt"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$after_goal"
  diff -q "$before_goal" "$after_goal" >/dev/null || { echo "builder失敗時にauto:goalの既存内容が保持されなかった:"; diff "$before_goal" "$after_goal" || true; return 1; }

  grep -q "auto:done:begin" "$daily" || { echo "auto:doneマーカーが消えた"; return 1; }
  grep -qE '^- \[auto\] 集計' "$daily" || { echo "auto:alignが更新されていない（renderが継続していない疑い）"; return 1; }

  return 0
)

# ============================================================
# t15: build-done/build-align内部での部品失敗握りつぶし防止（差し戻し2回目・重大1件）
# build-done.sh/build-align.shはcodex-pull.sh等の部品呼び出しを || true で握りつぶしていたため、
# 部品が失敗してもbuilder自体はexit 0になり、render.shの『builder失敗→applyスキップ』防御が
# 発動せず、既存内容がある状態でauto:done/alignが部分データで上書きされてしまっていた
# （レビュアーがcodex-pull失敗stubで実測）。
# auto:done/alignに実コンテンツがある状態でcodex-pullを失敗stub化し、render後も両マーカーの
# 内容が一切変化しないこと・警告がstderrに出ること・無関係なauto:goalは通常どおり更新される
# ことを検証する。
# ============================================================
t15_partial_component_failure_preserves_done_and_align() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  mkdir -p "$AIJOBS_BASE/done" "$CLAUDE_PROJECTS_BASE/proj1" "$workdir/data/gitrepo-t15"

  cat > "$CLAUDE_PROJECTS_BASE/proj1/sess-t15-1.jsonl" <<EOF
{"timestamp":"2026-07-02T01:00:00Z","cwd":"$workdir/data/gitrepo-t15"}
EOF
  touch -t 202607021305 "$CLAUDE_PROJECTS_BASE/proj1/sess-t15-1.jsonl"

  cat > "$AIJOBS_BASE/done/card-t15.md" <<'EOF'
担当: claude
出所: ready/card-t15.md
EOF
  touch -t 202607021200 "$AIJOBS_BASE/done/card-t15.md"

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  # 1回目: 正常render。auto:done/alignに実コンテンツ（保持されるべき「既存内容」）を作る。
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }
  grep -q "card-t15.md" "$daily" || { echo "前提崩れ: auto:doneに既存内容(doneカード)が無い"; return 1; }
  grep -qE '^- \[auto\] 集計.*対話ログ 1 件' "$daily" || { echo "前提崩れ: auto:alignに既存内容(対話ログ1件)が無い"; return 1; }

  before_done="$workdir/before-done.txt"
  before_align="$workdir/before-align.txt"
  before_goal="$workdir/before-goal.txt"
  sed -n '/auto:done:begin/,/auto:done:end/p' "$daily" > "$before_done"
  sed -n '/auto:align:begin/,/auto:align:end/p' "$daily" > "$before_align"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$before_goal"

  # codex-pull.sh をこのworkdir内だけ失敗stub化する（実際の障害原因は問わず、
  # build-done.sh/build-align.shが握りつぶさず非0で伝播することだけを検証する）。
  codex_pull_sh="$workdir/loops-registry/loops/renderer/scripts/codex-pull.sh"
  cat > "$codex_pull_sh" <<'EOF'
#!/usr/bin/env bash
echo "stub: 人為的な失敗" >&2
exit 1
EOF
  chmod +x "$codex_pull_sh"

  out="$("$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "codex-pull失敗時にrender.shのexitが0になった（伝播していない）"; return 1; }

  printf '%s\n' "$out" | grep -q "警告.*codex-pull.sh.*失敗" || { echo "codex-pull.shの失敗警告が出ていない。出力: $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*build-done.sh.*失敗.*auto:done" || { echo "build-done.shのskip警告が出ていない。出力: $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*build-align.sh.*失敗.*auto:align" || { echo "build-align.shのskip警告が出ていない。出力: $out"; return 1; }

  after_done="$workdir/after-done.txt"
  after_align="$workdir/after-align.txt"
  after_goal="$workdir/after-goal.txt"
  sed -n '/auto:done:begin/,/auto:done:end/p' "$daily" > "$after_done"
  sed -n '/auto:align:begin/,/auto:align:end/p' "$daily" > "$after_align"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$after_goal"

  diff -q "$before_done" "$after_done" >/dev/null || { echo "auto:doneの既存内容が保持されなかった:"; diff "$before_done" "$after_done" || true; return 1; }
  diff -q "$before_align" "$after_align" >/dev/null || { echo "auto:alignの既存内容が保持されなかった:"; diff "$before_align" "$after_align" || true; return 1; }

  # codex-pullに依存しないauto:goalは通常どおり更新され続ける（無関係な部品の失敗が波及しない）。
  diff -q "$before_goal" "$after_goal" >/dev/null || { echo "auto:goalの内容が想定外に変化した（無関係な失敗が波及した疑い）:"; diff "$before_goal" "$after_goal" || true; return 1; }

  return 0
)

# ============================================================
# t16: 子04a 3区画が描ける（今やっていること／待ち／計画ボード）
# orca ps fixture(2レーン)＋areas fixture(program1本＋単発plan1本)で、agent種別/state・
# 段階マーカー（人間確認待ち）・着手可能・未紐付けレーン・program子計画マップ・単発計画のいずれも
# 期待通り描画されること、かつ会話本文（マーカーに一致しないlastAssistantMessage）が漏れないことを
# 検証する。
# ============================================================
t16_board_sections_render_content() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  board_now="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"
  board_wait="$(sed -n '/auto:board-wait:begin/,/auto:board-wait:end/p' "$daily")"
  board_plans="$(sed -n '/auto:board-plans:begin/,/auto:board-plans:end/p' "$daily")"

  printf '%s' "$board_now" | grep -qF "統合設計子04a:ボード実況" || { echo "board-nowに子04aレーンが無い: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "claude:working" || { echo "board-nowにagent種別/stateが無い: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "段階: 人間確認待ち" || { echo "board-nowに段階マーカーが表示されていない: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "調査結果です" && { echo "board-nowに非マーカーの会話本文が漏れた: $board_now"; return 1; }

  printf '%s' "$board_wait" | grep -qF "人間確認待ち: 統合設計子04a:ボード実況" || { echo "board-waitに人間確認待ちが無い: $board_wait"; return 1; }
  printf '%s' "$board_wait" | grep -qF "着手可能: テスト統合プログラム 子02 テスト子計画B" || { echo "board-waitに着手可能が無い: $board_wait"; return 1; }
  printf '%s' "$board_wait" | grep -qF "未紐付けレーン: unknown-repo" || { echo "board-waitに未紐付けレーンが無い: $board_wait"; return 1; }

  printf '%s' "$board_plans" | grep -qF "テスト統合プログラム" || { echo "board-plansにprogramが無い: $board_plans"; return 1; }
  printf '%s' "$board_plans" | grep -qF "子02 テスト子計画B: 計画" || { echo "board-plansに子計画状態が無い: $board_plans"; return 1; }
  printf '%s' "$board_plans" | grep -qF "テスト単発計画" || { echo "board-plansに単発計画が無い: $board_plans"; return 1; }

  return 0
)

# ============================================================
# t17: 未紐付け検出（レーン＋コミットの両方。陽性・陰性の両ケース）
# displayNameに「子NN」が無いworktreeはレーン未紐付けとして検出される。
# また、orca psのどのレーンpathにも属さないgitリポジトリでの当日コミット（auto:log経由でpull済み）は
# 未紐付けコミットとして検出される（陽性）。紐付き済みレーン（子04a）は誤って未紐付け扱いされない。
# 加えて、紐付き済みレーンpath配下のサブディレクトリでのコミット（worktree直下でなくサブフォルダで
# セッションを開いた通常ケース）は未紐付けコミットとして誤検出されない（陰性・差し戻し1回目・指摘1の
# 回帰テスト。修正前はcwdとレーンpathの完全一致のみで判定しており、この陰性ケースを誤って
# 未紐付けと判定していた）。
# ============================================================
t17_board_unlinked_detection() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"

  # 陽性: orca psのどのレーンpathにも属さない外部リポジトリでのコミット。
  gitrepo="$workdir/data/gitrepo-t17"
  mkdir -p "$gitrepo" "$CLAUDE_PROJECTS_BASE/proj-t17"
  (
    cd "$gitrepo"
    git init -q
    git config user.email t17@t.example
    git config user.name "renderer-test"
    echo a > a.txt && git add a.txt && git commit -qm "t17: 未紐付けリポジトリでのコミット"
  )
  cat > "$CLAUDE_PROJECTS_BASE/proj-t17/sess-t17-1.jsonl" <<EOF
{"timestamp":"2026-07-02T01:00:00Z","cwd":"$gitrepo"}
EOF
  touch -t 202607021305 "$CLAUDE_PROJECTS_BASE/proj-t17/sess-t17-1.jsonl"

  # 陰性: 紐付き済みレーン(board-live-v1)path配下のサブディレクトリでのコミット。
  subdir_cwd="$BOARD_LIVE_V1_PATH/subdir"
  mkdir -p "$subdir_cwd" "$CLAUDE_PROJECTS_BASE/proj-t17-subdir"
  (
    cd "$subdir_cwd"
    echo b > b.txt && git add b.txt && git commit -qm "t17: 紐付き済みレーンのサブディレクトリでのコミット"
  )
  cat > "$CLAUDE_PROJECTS_BASE/proj-t17-subdir/sess-t17-2.jsonl" <<EOF
{"timestamp":"2026-07-02T01:30:00Z","cwd":"$subdir_cwd"}
EOF
  touch -t 202607021310 "$CLAUDE_PROJECTS_BASE/proj-t17-subdir/sess-t17-2.jsonl"

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  board_wait="$(sed -n '/auto:board-wait:begin/,/auto:board-wait:end/p' "$daily")"

  printf '%s' "$board_wait" | grep -qF "未紐付けレーン: unknown-repo" || { echo "未紐付けレーン検出に失敗: $board_wait"; return 1; }
  printf '%s' "$board_wait" | grep -qF "未紐付けコミット" || { echo "未紐付けコミット検出に失敗: $board_wait"; return 1; }
  printf '%s' "$board_wait" | grep -qF "$gitrepo" || { echo "未紐付けコミットのcwdが表示されていない: $board_wait"; return 1; }

  printf '%s' "$board_wait" | grep -qF "未紐付けレーン: board-live-v1" && { echo "紐付き済みレーンが誤って未紐付け判定された: $board_wait"; return 1; }
  printf '%s' "$board_wait" | grep -qF "$subdir_cwd" && { echo "紐付き済みレーン配下のサブディレクトリcwdが誤って未紐付けコミット判定された: $board_wait"; return 1; }

  return 0
)

# ============================================================
# t18: board区画を含むrenderの冪等性（同一fixtureで2回連続render→差分ゼロ）
# ============================================================
t18_board_idempotent() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/board-run1.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/board-run2.md"

  diff -q "$workdir/board-run1.md" "$workdir/board-run2.md" >/dev/null || { echo "board区画を含むrenderが2回連続で差分あり(冪等でない):"; diff "$workdir/board-run1.md" "$workdir/board-run2.md" || true; return 1; }

  grep -q "auto:board-now:begin" "$daily" || { echo "auto:board-nowマーカーが消えた"; return 1; }

  return 0
)

# ============================================================
# t19: orca ps失敗時の区画温存（auto:board-now/auto:board-waitの既存内容が保持される）
# 1回目は正常render。2回目はORCA_PS_CMDを失敗stub化し、rc非0・警告・auto:board-now/board-waitの
# 既存内容保持・無関係なauto:goalは通常どおり更新継続、を検証する（t14/t15と同じ設計規律）。
# ============================================================
t19_board_orca_failure_preserves() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }
  grep -qF "統合設計子04a:ボード実況" "$daily" || { echo "前提崩れ: auto:board-nowに実コンテンツが無い"; return 1; }

  before_now="$workdir/before-board-now.txt"
  before_wait="$workdir/before-board-wait.txt"
  before_goal="$workdir/before-goal.txt"
  sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily" > "$before_now"
  sed -n '/auto:board-wait:begin/,/auto:board-wait:end/p' "$daily" > "$before_wait"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$before_goal"

  ORCA_PS_CMD="false"
  export ORCA_PS_CMD

  out="$("$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "orca ps失敗時にrender.shのexitが0になった(伝播していない)"; return 1; }

  printf '%s\n' "$out" | grep -q "警告.*orca-ps-snapshot.sh.*失敗" || { echo "orca-ps-snapshot.shの失敗警告が出ていない。出力: $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*build-board-now.sh.*失敗.*auto:board-now" || { echo "build-board-now.shのskip警告が出ていない。出力: $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*build-board-wait.sh.*失敗.*auto:board-wait" || { echo "build-board-wait.shのskip警告が出ていない。出力: $out"; return 1; }

  after_now="$workdir/after-board-now.txt"
  after_wait="$workdir/after-board-wait.txt"
  after_goal="$workdir/after-goal.txt"
  sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily" > "$after_now"
  sed -n '/auto:board-wait:begin/,/auto:board-wait:end/p' "$daily" > "$after_wait"
  sed -n '/auto:goal:begin/,/auto:goal:end/p' "$daily" > "$after_goal"

  diff -q "$before_now" "$after_now" >/dev/null || { echo "auto:board-nowの既存内容が保持されなかった:"; diff "$before_now" "$after_now" || true; return 1; }
  diff -q "$before_wait" "$after_wait" >/dev/null || { echo "auto:board-waitの既存内容が保持されなかった:"; diff "$before_wait" "$after_wait" || true; return 1; }
  diff -q "$before_goal" "$after_goal" >/dev/null || { echo "無関係なauto:goalが想定外に変化した:"; diff "$before_goal" "$after_goal" || true; return 1; }

  return 0
)

# ============================================================
# t20: cockpit段階イベント(COCKPIT_EVENTS_FILE)の反映（統合program子04b）
# cockpit.shのsendが記録するJSONL(worktree一致・event=send・stage非null)の最新段階が
# auto:board-nowのレーン行末に「イベント段階:…」として併記されること。イベントが無いレーン
# (unknown-repo)には付与されないこと・会話本文は漏れないことも確認する。
# ============================================================
t20_board_now_shows_latest_stage_from_events() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"

  COCKPIT_EVENTS_FILE="$workdir/data/cockpit-events.jsonl"
  cat > "$COCKPIT_EVENTS_FILE" <<EOF
{"ts":"2026-07-02T01:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"send","stage":"実装"}
{"ts":"2026-07-02T03:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"send","stage":"実装レビュー"}
{"ts":"2026-07-02T02:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"up","stage":null}
EOF
  export COCKPIT_EVENTS_FILE

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  board_now="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"

  printf '%s' "$board_now" | grep -qF "統合設計子04a:ボード実況" || { echo "前提崩れ: 子04aレーンが無い: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "イベント段階:実装レビュー" || { echo "最新段階(実装レビュー)が併記されていない: $board_now"; return 1; }
  # ts最大のstage(実装レビュー)だけが残り、古いstage(実装)の値では上書きされていないことを
  # 行末一致で確認する（"実装"は"実装レビュー"の接頭辞なので単純containsでは判定できない）。
  printf '%s' "$board_now" | grep -qE "イベント段階:実装$" && { echo "古い段階(実装)が最新扱いされた: $board_now"; return 1; }

  unknown_line="$(printf '%s' "$board_now" | grep -F "unknown-repo" || true)"
  printf '%s' "$unknown_line" | grep -qF "イベント段階:" && { echo "イベント未紐付けのレーンに段階が誤って付与された: $unknown_line"; return 1; }

  return 0
)

# ============================================================
# t21: cockpit段階イベントが無い/壊れていても従来表示のまま動く（後方互換）
# サブケース1: COCKPIT_EVENTS_FILE未設定(既定パスに実ファイル無し)。
# サブケース2: COCKPIT_EVENTS_FILEが存在するがJSONとして解釈不能な内容のみ。
# いずれもrenderはexit 0・auto:board-nowに「イベント段階:」が出ない・既存の描画内容は不変。
# ============================================================
t21_board_now_backward_compat_without_events() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"

  # --- サブケース1: COCKPIT_EVENTS_FILE未設定 ---
  out1="$("$render" 2026-07-02 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "sub1: exit非0 ($rc1): $out1"; return 1; }
  board_now1="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"
  printf '%s' "$board_now1" | grep -qF "統合設計子04a:ボード実況" || { echo "sub1: 子04aレーンが無い: $board_now1"; return 1; }
  printf '%s' "$board_now1" | grep -qF "イベント段階:" && { echo "sub1: イベントファイル未設定なのに段階が付与された: $board_now1"; return 1; }

  # --- サブケース2: COCKPIT_EVENTS_FILEが壊れている(JSONとして解釈不能な行のみ) ---
  COCKPIT_EVENTS_FILE="$workdir/data/broken-events.jsonl"
  printf 'これはJSONではない\n{ 壊れた行\n' > "$COCKPIT_EVENTS_FILE"
  export COCKPIT_EVENTS_FILE

  out2="$("$render" 2026-07-02 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "sub2: exit非0 ($rc2): $out2"; return 1; }
  board_now2="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"
  printf '%s' "$board_now2" | grep -qF "統合設計子04a:ボード実況" || { echo "sub2: 子04aレーンが無い: $board_now2"; return 1; }
  printf '%s' "$board_now2" | grep -qF "イベント段階:" && { echo "sub2: 壊れたイベントファイルなのに段階が付与された: $board_now2"; return 1; }

  [ "$board_now1" = "$board_now2" ] || { echo "sub1とsub2でauto:board-nowの内容が異なる(後方互換崩れ):"; diff <(printf '%s' "$board_now1") <(printf '%s' "$board_now2") || true; return 1; }

  return 0
)

# ============================================================
# t22: 明日へ朝転記（前日「## 明日へ」に中身あり→当日の逆算直後＝## 今日のTODO直前へ区画生成）
# 前日デイリー(2026-07-01)の「## 明日へ」に手書き中身を置き、当日(2026-07-02)renderで
# auto:tomorrow-carry区画が「auto:align:end の後・## 今日のTODO の前」に生成され、中身と
# 「### 明日へ（前日日付 から）」見出しが入ること、テンプレの「## 明日へ」節自体も残ることを検証する。
# ============================================================
t22_tomorrow_carry_basic() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"

  prev="$GOAL_BASE/デイリー/2026/07/2026-07-01.md"
  mkdir -p "$(dirname "$prev")"
  cat > "$prev" <<'EOF'
# デイリー 2026-07-01（Wed）

## 逆算

## 今日のTODO
- [ ]

## ログ

## 明日へ
- 明日タスクA
- 明日タスクB
EOF

  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  out="$("$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  [ -f "$daily" ] || { echo "デイリー未生成"; return 1; }

  carry="$(sed -n '/auto:tomorrow-carry:begin/,/auto:tomorrow-carry:end/p' "$daily")"
  printf '%s' "$carry" | grep -qF "### 明日へ（2026-07-01 から）" || { echo "転記区画の見出しが無い: $carry"; return 1; }
  printf '%s' "$carry" | grep -qF "明日タスクA" || { echo "前日の中身(タスクA)が転記されていない: $carry"; return 1; }
  printf '%s' "$carry" | grep -qF "明日タスクB" || { echo "前日の中身(タスクB)が転記されていない: $carry"; return 1; }

  # 配置: auto:align:end の後・## 今日のTODO の前（逆算直後）
  align_ln="$(grep -nE '^<!-- auto:align:end' "$daily" | head -1 | cut -d: -f1)"
  begin_ln="$(grep -nE '^<!-- auto:tomorrow-carry:begin' "$daily" | head -1 | cut -d: -f1)"
  end_ln="$(grep -nE '^<!-- auto:tomorrow-carry:end' "$daily" | head -1 | cut -d: -f1)"
  todo_ln="$(grep -nE '^## 今日のTODO' "$daily" | head -1 | cut -d: -f1)"
  { [ -n "$align_ln" ] && [ -n "$begin_ln" ] && [ -n "$end_ln" ] && [ -n "$todo_ln" ]; } || { echo "位置検出に失敗: align=$align_ln begin=$begin_ln end=$end_ln todo=$todo_ln"; return 1; }
  { [ "$align_ln" -lt "$begin_ln" ] && [ "$begin_ln" -lt "$end_ln" ] && [ "$end_ln" -lt "$todo_ln" ]; } || { echo "区画が逆算直後(align:end<begin<end<今日のTODO)に無い: align=$align_ln begin=$begin_ln end=$end_ln todo=$todo_ln"; return 1; }

  # テンプレの「## 明日へ」節そのものは当日デイリーにも残る（手書き欄）
  grep -qE '^## 明日へ[[:space:]]*$' "$daily" || { echo "テンプレの## 明日へ節が当日デイリーに無い"; return 1; }
  # 転記区画は ## 見出しを新設しない（### で作る）
  printf '%s' "$carry" | grep -qE '^## ' && { echo "転記区画が## 見出しを新設した(### のはず): $carry"; return 1; }

  return 0
)

# ============================================================
# t23: 明日へ朝転記の冪等性（中身ありで2回連続render→差分ゼロ・区画は1つだけ）
# ============================================================
t23_tomorrow_carry_idempotent() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"

  prev="$GOAL_BASE/デイリー/2026/07/2026-07-01.md"
  mkdir -p "$(dirname "$prev")"
  cat > "$prev" <<'EOF'
# デイリー 2026-07-01（Wed）

## 逆算

## 今日のTODO
- [ ]

## 明日へ
- 冪等チェック用タスク
EOF

  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/carry-run1.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  cp "$daily" "$workdir/carry-run2.md"

  diff -q "$workdir/carry-run1.md" "$workdir/carry-run2.md" >/dev/null || { echo "転記を含むrenderが2回連続で差分あり(冪等でない):"; diff "$workdir/carry-run1.md" "$workdir/carry-run2.md" || true; return 1; }

  begin_count="$(grep -cE '^<!-- auto:tomorrow-carry:begin' "$daily" || true)"
  [ "$begin_count" -eq 1 ] || { echo "転記区画が1つでない(begin=$begin_count・重複転記の疑い)"; return 1; }
  grep -qF "冪等チェック用タスク" "$daily" || { echo "前日の中身が転記されていない(テスト自体が無意味)"; return 1; }

  return 0
)

# ============================================================
# t24: 前日「## 明日へ」が空なら転記区画を生成しない／前日が空になったら既存区画を除去する
# サブA: 前日の明日へがプレースホルダ(裸の-)のみ→当日にtomorrow-carryマーカーが一切出ない。
# サブB: いったん中身ありで区画生成→前日を空に書き換えて再render→区画が除去される(空区画を残さない)。
# ============================================================
t24_tomorrow_carry_empty_skips_and_removes() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  prev="$GOAL_BASE/デイリー/2026/07/2026-07-01.md"
  mkdir -p "$(dirname "$prev")"

  # --- サブA: 前日の明日へがプレースホルダのみ ---
  cat > "$prev" <<'EOF'
# デイリー 2026-07-01（Wed）

## 逆算

## 明日へ
-
EOF
  out="$("$render" 2026-07-02 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "subA: exit非0 ($rc): $out"; return 1; }
  grep -qE '^<!-- auto:tomorrow-carry:' "$daily" && { echo "subA: 前日が空(裸の-のみ)なのに転記区画が生成された"; return 1; }
  # 逆算とTODOの間に空のauto区画が残っていない＝## 今日のTODO は健在
  grep -qE '^## 今日のTODO' "$daily" || { echo "subA: ## 今日のTODO が消えた"; return 1; }

  # --- サブB: 中身あり→区画生成→前日を空に→区画除去 ---
  cat > "$prev" <<'EOF'
# デイリー 2026-07-01（Wed）

## 逆算

## 明日へ
- 一時的な中身
EOF
  "$render" 2026-07-02 >/dev/null 2>&1
  grep -qE '^<!-- auto:tomorrow-carry:begin' "$daily" || { echo "subB: 中身ありなのに区画が生成されなかった(前提崩れ)"; return 1; }

  # 前日を空(プレースホルダ)に書き換え→再render→区画が除去されるはず
  cat > "$prev" <<'EOF'
# デイリー 2026-07-01（Wed）

## 逆算

## 明日へ
-
EOF
  before_removed="$workdir/before-removed.md"
  cp "$daily" "$before_removed"
  "$render" 2026-07-02 >/dev/null 2>&1
  grep -qE '^<!-- auto:tomorrow-carry:' "$daily" && { echo "subB: 前日が空になったのに転記区画が残った(空区画を残さないの違反): $(sed -n '/tomorrow-carry/p' "$daily")"; return 1; }
  # 区画除去後も再度renderして安定（冪等・二重除去で壊れない）
  "$render" 2026-07-02 >/dev/null 2>&1
  after_stable="$workdir/after-stable.md"
  cp "$daily" "$after_stable"
  "$render" 2026-07-02 >/dev/null 2>&1
  diff -q "$after_stable" "$daily" >/dev/null || { echo "subB: 区画除去後のrenderが冪等でない:"; diff "$after_stable" "$daily" || true; return 1; }

  return 0
)

# ============================================================
# t25: cockpit管轄イベント(owner)の反映（owner-view-read・先行部品①はf2d5f7bで実装済み）
# cockpit.shのsendが記録するJSONLのowner(--owner)が、stageと同じ「event=sendの最新ts」規約で
# auto:board-nowのレーン行末に「イベント段階:…」の隣へ「管轄:…」として併記されること。
# 古いts(全体管理者)ではなく最新ts(中間指揮官1)のownerが採用されること、イベント未紐付けの
# レーン(unknown-repo)には付与されないことを確認する。
# ============================================================
t25_board_now_shows_owner_from_events() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"

  COCKPIT_EVENTS_FILE="$workdir/data/cockpit-events.jsonl"
  cat > "$COCKPIT_EVENTS_FILE" <<EOF
{"ts":"2026-07-02T01:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"send","stage":"実装","owner":"全体管理者"}
{"ts":"2026-07-02T03:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"send","stage":"実装レビュー","owner":"中間指揮官1"}
{"ts":"2026-07-02T02:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"up","stage":null,"owner":null}
EOF
  export COCKPIT_EVENTS_FILE

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  board_now="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"

  printf '%s' "$board_now" | grep -qF "統合設計子04a:ボード実況" || { echo "前提崩れ: 子04aレーンが無い: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "管轄:中間指揮官1" || { echo "最新owner(中間指揮官1)が併記されていない: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "管轄:全体管理者" && { echo "古いowner(全体管理者)が最新扱いされた: $board_now"; return 1; }

  unknown_line="$(printf '%s' "$board_now" | grep -F "unknown-repo" || true)"
  printf '%s' "$unknown_line" | grep -qF "管轄:" && { echo "イベント未紐付けのレーンに管轄が誤って付与された: $unknown_line"; return 1; }

  return 0
)

# ============================================================
# t26: ownerが無い/nullの旧イベントは「管轄:」を出さない（後方互換・owner-view-read）。
# f2d5f7b以前のイベント行を模したownerキー欠落のJSONLでも、既存のstage併記は壊れず
# 「管轄:」だけが出ないことを確認する。
# ============================================================
t26_board_now_owner_absent_stays_silent() (
  set -euo pipefail
  workdir="$(new_workdir)"
  setup_common_env "$workdir"
  setup_board_fixtures "$workdir"

  COCKPIT_EVENTS_FILE="$workdir/data/cockpit-events-legacy.jsonl"
  cat > "$COCKPIT_EVENTS_FILE" <<EOF
{"ts":"2026-07-02T01:00:00Z","repo":"Private","branch":"nextlevelkitamura-alt/board-live-v1","worktree":"$BOARD_LIVE_V1_PATH","terminal":"t1","event":"send","stage":"実装"}
EOF
  export COCKPIT_EVENTS_FILE

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-02.md"
  "$render" 2026-07-02 >/dev/null 2>&1
  [ -f "$daily" ] || { echo "前提崩れ: デイリー未生成"; return 1; }

  board_now="$(sed -n '/auto:board-now:begin/,/auto:board-now:end/p' "$daily")"
  printf '%s' "$board_now" | grep -qF "イベント段階:実装" || { echo "ownerキー欠落の旧イベントでstage併記が壊れた: $board_now"; return 1; }
  printf '%s' "$board_now" | grep -qF "管轄:" && { echo "ownerキーが無い旧イベントで管轄が誤って付与された: $board_now"; return 1; }

  return 0
)

# ============================================================
run_test t1_daily_auto_generate
run_test t2_human_lines_untouched
run_test t3_idempotency
run_test t4_legacy_compat
run_test t5_codex_jst_boundary
run_test t6_no_carry_progress
run_test t7_debounce
run_test t8_secret_discipline
run_test t9_default_template_is_repo_internal
run_test t10_missing_log_marker_skips_cleanly
run_test t11_debounce_no_lost_event_during_render
run_test t12_codex_pull_performance_and_correctness
run_test t13_goal_base_not_exported_reproduces_and_fixed
run_test t14_builder_failure_preserves_marker_content
run_test t15_partial_component_failure_preserves_done_and_align
run_test t16_board_sections_render_content
run_test t17_board_unlinked_detection
run_test t18_board_idempotent
run_test t19_board_orca_failure_preserves
run_test t20_board_now_shows_latest_stage_from_events
run_test t21_board_now_backward_compat_without_events
run_test t22_tomorrow_carry_basic
run_test t23_tomorrow_carry_idempotent
run_test t24_tomorrow_carry_empty_skips_and_removes
run_test t25_board_now_shows_owner_from_events
run_test t26_board_now_owner_absent_stays_silent

echo "=== 結果: PASS=$pass_count FAIL=$fail_count ==="
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
