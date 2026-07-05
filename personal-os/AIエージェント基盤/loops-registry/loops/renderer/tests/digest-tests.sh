#!/usr/bin/env bash
# renderer / tests / digest-tests.sh — digest.sh（当日repo別コミット＋cockpitレーン段階所要時間の
# LLMダイジェスト）のテストスイート。実デイリー（~/Private/personal-os/my-brain/ゴール/デイリー/）・
# 実HOME・実API（`claude` CLI）には一切触れない。各テストは独立の mktemp -d ワークコピー上で
# env上書きだけで完結させる。
#
# 安全側デフォルト: スイート全体の既定として DIGEST_LLM_CMD／DIGEST_EVENTS_FILE／
# DIGEST_REPO_OVERVIEW／DIGEST_REPO_PATH_* を実HOME配下ではない非実在パスへ向けておく
# （digest.shの環境変数既定値は $HOME 配下の実パスのため、テストが上書きし忘れても実API呼び出し・
# 実repo参照に到達しないようにするための保険）。各テストは必要なものだけ個別に上書きする。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_DIR="$(cd "$TESTS_DIR/.." && pwd)"
LOOPS_DIR="$(cd "$RENDERER_DIR/.." && pwd)"

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

# --- スイート全体の安全側デフォルト ---
default_safe_dir="$(mktemp -d "${TMPDIR:-/tmp}/digest-test-default-safe.XXXXXX")"
workdirs+=("$default_safe_dir")

default_llm_fail_stub="$default_safe_dir/llm-fail-by-default.sh"
cat > "$default_llm_fail_stub" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
exit 1
EOF
chmod +x "$default_llm_fail_stub"

export GOAL_BASE="$default_safe_dir/unused-goal-base"
export DIGEST_LLM_CMD="$default_llm_fail_stub"
export DIGEST_EVENTS_FILE="$default_safe_dir/no-events.jsonl"
export DIGEST_REPO_OVERVIEW="$default_safe_dir/no-overview.md"
export DIGEST_REPO_PATH_AIKIBAN="$default_safe_dir/no-repo-a"
export DIGEST_REPO_PATH_PRIVATE="$default_safe_dir/no-repo-b"
export DIGEST_REPO_PATH_SHIGOTO="$default_safe_dir/no-repo-c"
export DIGEST_REPO_PATH_FOCUSMAP="$default_safe_dir/no-repo-d"

# --- ヘルパ ---

new_workdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/digest-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer/scripts" "$d/loops-registry/loops/renderer/templates" "$d/loops-registry/loops/daily-digest/scripts"
  cp -R "$RENDERER_DIR/scripts/." "$d/loops-registry/loops/renderer/scripts/"
  cp -R "$RENDERER_DIR/templates/." "$d/loops-registry/loops/renderer/templates/"
  cp -R "$LOOPS_DIR/daily-digest/scripts/." "$d/loops-registry/loops/daily-digest/scripts/"
  printf '%s' "$d"
}

digest_bin() { printf '%s/loops-registry/loops/renderer/scripts/digest.sh' "$1"; }

# usage: make_daily_file <goal_base> <date_str>  -> stdout: 生成した当日デイリーの絶対パス
# テンプレ(auto:digest節あり)からプレースホルダを置換して作る。GOAL_BASEのexportは呼び出し側の責務
# （本関数はコマンド置換($())で呼ぶためサブシェル内実行になり、ここでexportしても呼び出し元には
# 伝播しないことに注意）。
make_daily_file() {
  local goal_base="$1" date_str="$2" y rest m daily
  y="${date_str%%-*}"; rest="${date_str#*-}"; m="${rest%%-*}"
  mkdir -p "$goal_base/デイリー/$y/$m"
  daily="$goal_base/デイリー/$y/$m/$date_str.md"
  cp "$RENDERER_DIR/templates/デイリー.md" "$daily"
  sed -i '' -e "s/<YYYY-MM-DD>/$date_str/g" -e 's/<曜>/木/g' -e "s/<YYYY>/$y/g" "$daily"
  printf '%s' "$daily"
}

# auto:digest節（見出し＋begin/endマーカー）を丸ごと削り、節が無い旧デイリー相当を作る。
strip_digest_section() {
  local file="$1"
  sed -i '' '/^## 今日のダイジェスト$/,/^<!-- auto:digest:end -->$/d' "$file"
}

make_git_repo() {
  local path="$1"
  mkdir -p "$path"
  (
    cd "$path"
    git init -q
    git config user.email digest-test@t.example
    git config user.name digest-test
  )
}

# usage: make_git_worktree <main_repo> <worktree_path> <branch>
# 実際の `git worktree add` でリンクworktreeを作る（そこでは .git がディレクトリではなく
# ファイルになる。orca-cockpitが作るworktreeも同形のため、repo_section()の`.git`存在判定が
# `-e`ではなく`-d`のままだと常に「無い」扱いになるバグを再現・検出するための実体）。
make_git_worktree() {
  local main_repo="$1" wt_path="$2" branch="$3"
  mkdir -p "$(dirname "$wt_path")"
  (
    cd "$main_repo"
    git worktree add -q -b "$branch" "$wt_path" >/dev/null
  )
}

# usage: commit_on <repo> <ISO日時> <subject> <ファイル名>
commit_on() {
  local path="$1" iso_dt="$2" msg="$3" fname="$4"
  (
    cd "$path"
    echo "$msg" > "$fname"
    git add "$fname"
    GIT_AUTHOR_DATE="$iso_dt" GIT_COMMITTER_DATE="$iso_dt" git commit -qm "$msg" >/dev/null
  )
}

# usage: make_stdin_capture_llm <capture先ファイル> -> stdout: 生成したstubスクリプトのパス
# stdin(=プロンプト全文)をcapture先へ書き出し、固定文言を返すLLMスタブ。実API不使用。
make_stdin_capture_llm() {
  local capture="$1"
  local stub="${capture}.sh"
  cat > "$stub" <<EOF
#!/usr/bin/env bash
cat > "$capture"
echo "- [auto] キャプチャ済み"
EOF
  chmod +x "$stub"
  printf '%s' "$stub"
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

# ============================================================
# d1: 冪等（同一入力で2回連続実行→差分ゼロ）
# ============================================================
d1_idempotent_replace() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  repo1="$workdir/data/repo1"
  make_git_repo "$repo1"
  commit_on "$repo1" "2026-07-02T03:00:00" "最初のコミット" a.txt
  commit_on "$repo1" "2026-07-02T04:00:00" "2番目のコミット" b.txt

  llm_stub="$workdir/data/llm-fixed.sh"
  cat > "$llm_stub" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
echo "- [auto] スタブ固定ダイジェスト"
EOF
  chmod +x "$llm_stub"

  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_LLM_CMD="$llm_stub"
  export DIGEST_REPO_PATH_AIKIBAN="$repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/run1.err"
  cp "$daily" "$workdir/run1.md"
  "$digest" "$date_str" >/dev/null 2>"$workdir/run2.err"
  cp "$daily" "$workdir/run2.md"

  diff -q "$workdir/run1.md" "$workdir/run2.md" >/dev/null || { echo "2回連続実行で差分が出た(冪等でない):"; diff "$workdir/run1.md" "$workdir/run2.md" || true; return 1; }
  grep -qF "スタブ固定ダイジェスト" "$daily" || { echo "ダイジェスト内容が反映されていない"; return 1; }
  return 0
)

# ============================================================
# d2: 節自動挿入（auto:digest節が無い旧デイリーに「今日終わったこと」直前へ挿入・人間行不可侵・
#     挿入後の再実行でも重複しない）
# ============================================================
d2_section_auto_insert() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"
  strip_digest_section "$daily"
  grep -q "auto:digest:begin" "$daily" && { echo "前提崩れ: 節除去に失敗した"; return 1; }

  # 人間の実績行を「今日終わったこと」節に注入（マーカー外・不可侵確認用）
  awk '/^## 今日終わったこと/ { print; getline; print "- 人間の実績メモ"; next } { print }' "$daily" > "$daily.tmp" && mv "$daily.tmp" "$daily"

  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$workdir/data/captured.txt")"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d2.err"

  grep -qE '^## 今日のダイジェスト$' "$daily" || { echo "節見出しが挿入されていない"; return 1; }
  grep -qE '^<!-- auto:digest:begin' "$daily" || { echo "auto:digest begin無し"; return 1; }
  grep -qE '^<!-- auto:digest:end -->' "$daily" || { echo "auto:digest end無し"; return 1; }
  grep -qF "人間の実績メモ" "$daily" || { echo "人間行が消えた"; return 1; }

  order="$(grep -nE '^## 今日のダイジェスト$|^## 今日終わったこと$' "$daily" | cut -d: -f2)"
  expected='## 今日のダイジェスト
## 今日終わったこと'
  [ "$order" = "$expected" ] || { echo "挿入位置が不正: $order"; return 1; }

  cp "$daily" "$workdir/after1.md"
  "$digest" "$date_str" >/dev/null 2>>"$workdir/d2.err"
  cp "$daily" "$workdir/after2.md"
  diff -q "$workdir/after1.md" "$workdir/after2.md" >/dev/null || { echo "節挿入後の再実行で内容が変化した(節が重複した疑い):"; diff "$workdir/after1.md" "$workdir/after2.md" || true; return 1; }

  count="$(grep -cE '^## 今日のダイジェスト$' "$daily")"
  [ "$count" -eq 1 ] || { echo "節見出しが重複している(件数=$count)"; return 1; }

  return 0
)

# ============================================================
# d3: LLM stub経由で機械集計＋repo概要.mdの内容がプロンプトへ渡り、LLM出力がそのままデイリーへ反映される
# ============================================================
d3_llm_receives_context_and_output_applied() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  repo1="$workdir/data/repo1"
  make_git_repo "$repo1"
  commit_on "$repo1" "2026-07-02T03:00:00" "識別子コミットXYZ" a.txt

  overview="$workdir/data/repo概要.md"
  printf '# repo概要\n識別子概要ABC\n' > "$overview"

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$overview"
  export DIGEST_REPO_PATH_AIKIBAN="$repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d3.err"

  grep -qF "識別子コミットXYZ" "$capture" || { echo "機械集計(コミットsubject)がLLMプロンプトに渡っていない"; return 1; }
  grep -qF "識別子概要ABC" "$capture" || { echo "repo概要.mdの内容がLLMプロンプトに渡っていない"; return 1; }
  grep -qF "キャプチャ済み" "$daily" || { echo "LLM出力がデイリーへ反映されていない"; return 1; }

  return 0
)

# ============================================================
# d4: LLM失敗(非0終了)時は機械集計だけの素朴なダイジェストへフォールバックし、exit 0で警告を出す
# ============================================================
d4_llm_failure_fallback() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  repo1="$workdir/data/repo1"
  make_git_repo "$repo1"
  commit_on "$repo1" "2026-07-02T03:00:00" "フォールバック確認用コミット" a.txt

  llm_fail="$workdir/data/llm-fail.sh"
  cat > "$llm_fail" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
echo "疑似エラー" >&2
exit 1
EOF
  chmod +x "$llm_fail"

  export DIGEST_LLM_CMD="$llm_fail"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0($rc): $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*LLM要約に失敗" || { echo "フォールバック警告が出ていない: $out"; return 1; }
  grep -qF "フォールバック確認用コミット" "$daily" || { echo "機械集計フォールバックにコミットsubjectが出ていない"; return 1; }
  grep -qF "LLM要約に失敗したため機械集計のみを表示" "$daily" || { echo "フォールバック注記が無い"; return 1; }

  return 0
)

# ============================================================
# d5: LLMがexit 0でも出力が空ならフォールバックする
# ============================================================
d5_llm_empty_output_fallback() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  llm_empty="$workdir/data/llm-empty.sh"
  cat > "$llm_empty" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
exit 0
EOF
  chmod +x "$llm_empty"

  export DIGEST_LLM_CMD="$llm_empty"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0($rc): $out"; return 1; }
  grep -qF "LLM要約に失敗したため機械集計のみを表示" "$daily" || { echo "空出力なのにフォールバックしていない"; return 1; }
  return 0
)

# ============================================================
# d6: cockpit段階イベントの所要時間計算（ts差分・分単位）が正しい
# lane-a: up→実装(8分後)→実装レビュー(さらに15分後)→down(さらに12分後)
# lane-b: 修正へsendのみ(当日中に後続イベント無し)→進行中
# ============================================================
d6_event_duration_calculation() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  events="$workdir/data/events.jsonl"
  cat > "$events" <<'EOF'
{"ts": "2026-07-02T03:00:00Z", "repo": "AIエージェント基盤", "branch": "lane-a", "worktree": "/x/lane-a", "terminal": null, "event": "up", "stage": null}
{"ts": "2026-07-02T03:08:00Z", "repo": "AIエージェント基盤", "branch": "lane-a", "worktree": "/x/lane-a", "terminal": "t1", "event": "send", "stage": "実装"}
{"ts": "2026-07-02T03:23:00Z", "repo": "AIエージェント基盤", "branch": "lane-a", "worktree": "/x/lane-a", "terminal": "t1", "event": "send", "stage": "実装レビュー"}
{"ts": "2026-07-02T03:35:00Z", "repo": "AIエージェント基盤", "branch": "lane-a", "worktree": "/x/lane-a", "terminal": null, "event": "down", "stage": null}
{"ts": "2026-07-02T05:00:00Z", "repo": "AIエージェント基盤", "branch": "lane-b", "worktree": "/x/lane-b", "terminal": "t2", "event": "send", "stage": "修正"}
EOF

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$events"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d6.err"

  grep -qF "レーン2本（1完了・1進行中）" "$capture" || { echo "レーン集計サマリが不一致:"; cat "$capture"; return 1; }
  grep -qF "実装(15分)" "$capture" || { echo "実装の所要時間が不一致:"; cat "$capture"; return 1; }
  grep -qF "実装レビュー(12分)" "$capture" || { echo "実装レビューの所要時間が不一致:"; cat "$capture"; return 1; }
  grep -qF "修正(進行中)" "$capture" || { echo "進行中表記が不一致:"; cat "$capture"; return 1; }

  return 0
)

# ============================================================
# d7: JST日付境界（UTC→JST変換）で当日行だけが集計対象になる
# 2026-07-02T14:59:00Z = JST 2026-07-02 23:59（当日に含む）
# 2026-07-02T15:01:00Z = JST 2026-07-03 00:01（翌日扱い・当日には含めない）
# ============================================================
d7_jst_day_boundary() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  events="$workdir/data/events.jsonl"
  cat > "$events" <<'EOF'
{"ts": "2026-07-02T14:59:00Z", "repo": "AIエージェント基盤", "branch": "in-day", "worktree": "/x/in-day", "terminal": "t1", "event": "send", "stage": "実装"}
{"ts": "2026-07-02T15:01:00Z", "repo": "AIエージェント基盤", "branch": "next-day", "worktree": "/x/next-day", "terminal": "t2", "event": "send", "stage": "実装"}
EOF

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$events"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d7.err"

  grep -qF "レーン1本" "$capture" || { echo "JST日付境界の判定が不一致:"; cat "$capture"; return 1; }
  grep -qF "in-day" "$capture" || { echo "境界内(JST同日)イベントが含まれていない:"; cat "$capture"; return 1; }
  grep -qF "next-day" "$capture" && { echo "翌日(JST)扱いのイベントが誤って含まれた:"; cat "$capture"; return 1; }

  return 0
)

# ============================================================
# d8: イベントファイル不在でもクラッシュせずレーン0件として扱う(best-effort)
# ============================================================
d8_missing_events_file_resilient() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$workdir/data/captured.txt")"
  export DIGEST_EVENTS_FILE="$workdir/data/does-not-exist/events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "イベントファイル不在でexit非0($rc): $out"; return 1; }
  grep -qE '^<!-- auto:digest:begin' "$daily" || { echo "auto:digest区画が更新されていない"; return 1; }
  grep -qF "レーン0本" "$workdir/data/captured.txt" || { echo "レーン0件扱いになっていない:"; cat "$workdir/data/captured.txt"; return 1; }

  return 0
)

# ============================================================
# d9: 当日デイリーが存在しない場合は警告してexit 0（デイリー生成はdigest.shの責務外）
# ============================================================
d9_missing_daily_file_warns_and_exits_zero() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"

  export DIGEST_LLM_CMD="$default_llm_fail_stub"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "デイリー不在でexit非0($rc): $out"; return 1; }
  printf '%s\n' "$out" | grep -q "警告.*デイリーファイルが無い" || { echo "警告が出ていない: $out"; return 1; }
  [ ! -f "$GOAL_BASE/デイリー/2026/07/$date_str.md" ] || { echo "デイリーファイルが生成されてしまった(digest.shの責務外のはず)"; return 1; }

  return 0
)

# ============================================================
# d10: 対象repoのパスが存在しない場合は「取得不可」と表示しクラッシュしない
# ============================================================
d10_missing_repo_path_shows_unavailable() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$workdir/data/no-events.jsonl"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-such-path-at-all"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "repoパス不在でexit非0($rc): $out"; return 1; }
  grep -qF "取得不可" "$capture" || { echo "repoパス不在の表示が無い:"; cat "$capture"; return 1; }

  return 0
)

# ============================================================
# d11: 当日events.jsonlに現れたworktree（固定4repo以外）がrepo別集計に載る。
# `git worktree add` 由来の実worktreeで検証する（.gitがファイルになるケースの回帰確認）。
# ============================================================
d11_event_worktree_included_in_repo_agg() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  main_repo="$workdir/data/main-repo"
  make_git_repo "$main_repo"
  commit_on "$main_repo" "2026-06-01T00:00:00" "mainの古いコミット" base.txt

  wt_path="$workdir/data/worktrees/lane-x"
  make_git_worktree "$main_repo" "$wt_path" "lane-x-branch"
  [ -f "$wt_path/.git" ] || { echo "前提崩れ: worktreeの.gitがファイルになっていない(git worktree addの挙動が想定と違う)"; return 1; }
  commit_on "$wt_path" "2026-07-02T03:00:00" "worktree由来コミット" work.txt

  events="$workdir/data/events.jsonl"
  cat > "$events" <<EOF
{"ts": "2026-07-02T03:05:00Z", "repo": "AIエージェント基盤", "branch": "lane-x-branch", "worktree": "$wt_path", "terminal": "t1", "event": "send", "stage": "実装"}
EOF

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$events"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d11.err"

  grep -qF "[repo] lane-x" "$capture" || { echo "worktree名がrepoラベルとして出ていない:"; cat "$capture"; return 1; }
  grep -qF "worktree由来コミット" "$capture" || { echo "worktree内のコミットが集計されていない:"; cat "$capture"; return 1; }

  return 0
)

# ============================================================
# d12: 当日events.jsonlのworktreeが既に消えている（ディスク上に存在しない）場合、
# 警告なし・出力なしで完全にスキップする（レーン終了後の削除は正常運用のため）。
# 同じevents.jsonlに実在するworktree（control）も混ぜ、そちらは集計に含まれることを
# 同時に確認する（worktree走査自体を一切行わない旧実装だと、消滅worktreeが出ないのは
# 当然の空振りで成立してしまい検証力が無いため。controlの出現を要求することで、
# 走査ロジックが実際に動いていることを保証する）。
# ============================================================
d12_vanished_worktree_skipped_silently() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  vanished_path="$workdir/data/worktrees/already-gone"

  control_path="$workdir/data/worktrees/still-here"
  make_git_repo "$control_path"
  commit_on "$control_path" "2026-07-02T03:00:00" "生存worktree確認用コミット" a.txt

  events="$workdir/data/events.jsonl"
  cat > "$events" <<EOF
{"ts": "2026-07-02T03:05:00Z", "repo": "AIエージェント基盤", "branch": "already-gone", "worktree": "$vanished_path", "terminal": "t1", "event": "send", "stage": "実装"}
{"ts": "2026-07-02T03:10:00Z", "repo": "AIエージェント基盤", "branch": "still-here", "worktree": "$control_path", "terminal": "t2", "event": "send", "stage": "実装"}
EOF

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$events"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$workdir/data/no-repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  out="$("$digest" "$date_str" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "消滅worktreeでexit非0($rc): $out"; return 1; }
  [ -z "$out" ] || { echo "消滅worktreeなのに警告/出力が出た: $out"; return 1; }

  # 「repo別」節だけを抜き出して判定する（レーン段階所要時間はイベントログ由来で消滅worktreeでも
  # 出て良い＝正しい挙動。git log収集対象からのみ除外されていればよい＝完全スキップ＝
  # そもそも[repo]見出しが作られない）。固定4repoは元々ダミーの非実在パスなので「取得不可」で
  # 正しく列挙される（この節に他repoの「取得不可」が含まれるのは正常）。
  repo_section_text="$(sed -n '/^=== repo別/,/^=== レーン段階所要時間/p' "$capture")"
  printf '%s\n' "$repo_section_text" | grep -qF "already-gone" && { echo "消滅worktreeがrepo別集計に載ってしまった:"; printf '%s\n' "$repo_section_text"; return 1; }
  printf '%s\n' "$repo_section_text" | grep -qF "生存worktree確認用コミット" || { echo "同時に投入した生存worktree(control)がrepo別集計に出ていない(worktree走査が動いていない疑い):"; printf '%s\n' "$repo_section_text"; return 1; }

  return 0
)

# ============================================================
# d13: 当日events.jsonlのworktreeが固定4repoのいずれかと同一パスの場合、二重集計しない。
# 同じevents.jsonlに固定repoと無関係な実在worktree（control）も混ぜ、そちらは通常どおり
# 集計に含まれることを同時に確認する（worktree走査を一切行わない旧実装だと、重複が
# 起きないのは当然の空振りで成立してしまい検証力が無いため。controlの出現を要求する
# ことで、走査ロジックが実際に動いていることを保証する）。
# ============================================================
d13_worktree_matching_fixed_repo_not_duplicated() (
  set -euo pipefail
  workdir="$(new_workdir)"
  date_str="2026-07-02"
  export GOAL_BASE="$workdir/data/goal-base"
  daily="$(make_daily_file "$GOAL_BASE" "$date_str")"

  repo1="$workdir/data/repo1"
  make_git_repo "$repo1"
  commit_on "$repo1" "2026-07-02T03:00:00" "重複確認用コミット" a.txt

  control_path="$workdir/data/worktrees/lane-y"
  make_git_repo "$control_path"
  commit_on "$control_path" "2026-07-02T03:00:00" "非重複worktree確認用コミット" b.txt

  events="$workdir/data/events.jsonl"
  cat > "$events" <<EOF
{"ts": "2026-07-02T03:05:00Z", "repo": "AIエージェント基盤", "branch": "main", "worktree": "$repo1", "terminal": "t1", "event": "send", "stage": "実装"}
{"ts": "2026-07-02T03:10:00Z", "repo": "AIエージェント基盤", "branch": "lane-y-branch", "worktree": "$control_path", "terminal": "t2", "event": "send", "stage": "実装"}
EOF

  capture="$workdir/data/captured.txt"
  export DIGEST_LLM_CMD="$(make_stdin_capture_llm "$capture")"
  export DIGEST_EVENTS_FILE="$events"
  export DIGEST_REPO_OVERVIEW="$workdir/data/no-overview.md"
  export DIGEST_REPO_PATH_AIKIBAN="$repo1"
  export DIGEST_REPO_PATH_PRIVATE="$workdir/data/no-repo2"
  export DIGEST_REPO_PATH_SHIGOTO="$workdir/data/no-repo3"
  export DIGEST_REPO_PATH_FOCUSMAP="$workdir/data/no-repo4"

  digest="$(digest_bin "$workdir")"
  "$digest" "$date_str" >/dev/null 2>"$workdir/d13.err"

  occurrences="$(grep -cF "重複確認用コミット" "$capture")"
  [ "$occurrences" -eq 1 ] || { echo "固定repoと同一パスのworktreeが二重集計された(出現数=$occurrences):"; cat "$capture"; return 1; }

  repo_label_count="$(grep -cE '^\[repo\] AIエージェント基盤$' "$capture")"
  [ "$repo_label_count" -eq 1 ] || { echo "AIエージェント基盤のrepoラベルが重複している(件数=$repo_label_count):"; cat "$capture"; return 1; }

  grep -qF "非重複worktree確認用コミット" "$capture" || { echo "同時に投入した無関係worktree(control)が集計に出ていない(worktree走査が動いていない疑い):"; cat "$capture"; return 1; }

  return 0
)

# ============================================================
run_test d1_idempotent_replace
run_test d2_section_auto_insert
run_test d3_llm_receives_context_and_output_applied
run_test d4_llm_failure_fallback
run_test d5_llm_empty_output_fallback
run_test d6_event_duration_calculation
run_test d7_jst_day_boundary
run_test d8_missing_events_file_resilient
run_test d9_missing_daily_file_warns_and_exits_zero
run_test d10_missing_repo_path_shows_unavailable
run_test d11_event_worktree_included_in_repo_agg
run_test d12_vanished_worktree_skipped_silently
run_test d13_worktree_matching_fixed_repo_not_duplicated

echo "=== 結果: PASS=$pass_count FAIL=$fail_count ==="
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
