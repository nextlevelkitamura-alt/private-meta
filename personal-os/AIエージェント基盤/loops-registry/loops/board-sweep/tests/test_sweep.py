#!/usr/bin/env python3
# board-sweep のテスト（envサンドボックス・fixtureボード・LLM stub・実ボード/実transcript非接触）。
# pytest互換（test_*関数・素のassert）。pytest未導入環境でも `python3 tests/test_sweep.py` で全件実行できる。
#
# 子計画05のレビュー項目カバー:
#   - unknown無変更（dry-run/apply両モードで行が1バイトも変わらない）
#   - [auto]根拠（自動finishの子entryに [auto]＋台帳名/証跡が入る）
#   - 自己登録なし（AIJOBS_RUN=1 伝播・sweep前後で行数が増えない）
#   - 失敗exit0無害（LLM失敗・タイムアウト・台帳パース失敗でも exit 0・ボード無変更）
#   - dry-run板不変（既定モードでボードが byte 単位で不変）
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, "..", "scripts"))
SWEEP = os.path.join(SCRIPTS, "sweep.py")
sys.path.insert(0, SCRIPTS)
import sweep as sweep_mod  # noqa: E402

board = sweep_mod.board
TODAY = "2099-01-02"
YDAY = "2099-01-01"

LEDGER_OK = """# 台帳（テスト用・確定済み）
## 朝架電J列
- 一致: repo=仕事; goal前方一致=朝架電
- 終わり: J列更新完了
- 確認: none
- 記載: 朝架電J列の定型更新を完了
- 判定: done
"""

LEDGER_DRAFT = LEDGER_OK + "- ドラフト・人間確認待ち\n"


# ---- fixture helpers ----

def wait_row(key, goal, now, repo, who, plan, t="10:00"):
    return f"- ⏸ {t} | {goal} | 今:{now} | {repo} | 実装 | {who} | 計画:{plan} <!-- s:{key} -->"


def write_board(goal_base, date_s, rows):
    y, m, _ = date_s.split("-")
    d = os.path.join(goal_base, y, m)
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, f"{date_s}.md")
    text = (f"# デイリー {date_s}\n\n## 動いているエージェント\n"
            + "\n".join(rows) + "\n\n## 終わったこと\n")
    open(p, "w", encoding="utf-8").write(text)
    return p


def make_env(tmp, ledger=LEDGER_OK, llm=None, extra=None):
    goal = os.path.join(tmp, "goal")
    tx = os.path.join(tmp, "tx")
    os.makedirs(goal, exist_ok=True)
    os.makedirs(tx, exist_ok=True)
    lp = os.path.join(tmp, "ledger.md")
    if ledger is not None:
        open(lp, "w", encoding="utf-8").write(ledger)
    env = dict(os.environ)
    for k in ("SWEEP_LLM_CMD", "AIJOBS_RUN", "SWEEP_BOARD_DIR"):
        env.pop(k, None)
    env.update({
        "GOAL_BASE": goal, "SESSION_BOARD_DATE": TODAY,
        "SESSION_BOARD_TX_ROOTS": tx, "SESSION_BOARD_NO_TURSO": "1",
        "SWEEP_LEDGER": lp, "SWEEP_APPLY_MAX": "3",
        "SWEEP_SILENCE_MIN": "60", "SWEEP_LEDGER_SILENCE_MIN": "30",
        "SWEEP_LLM_TIMEOUT": "10",
    })
    if llm:
        env["SWEEP_LLM_CMD"] = llm
    if extra:
        env.update(extra)
    return env, goal, tx


def make_rollout(tx, key, age_min=120, complete=True):
    """codex rollout 形式の fixture（末尾 task_complete・mtime を age_min 分前へ）。"""
    d = os.path.join(tx, "2099", "01", "02")
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, f"rollout-2099-01-02T09-00-00-{key}-aaaa-bbbb.jsonl")
    recs = [{"timestamp": "t", "type": "event_msg",
             "payload": {"type": "agent_message", "message": "作業中"}}]
    if complete:
        recs.append({"timestamp": "t", "type": "event_msg",
                     "payload": {"type": "task_complete",
                                 "last_agent_message": "完了しました"}})
    open(p, "w", encoding="utf-8").write("\n".join(json.dumps(r) for r in recs) + "\n")
    t = time.time() - age_min * 60
    os.utime(p, (t, t))
    return p


def make_llm_stub(tmp, verdicts, sleep=0):
    """SWEEP_LLM_CMD 用 stub。SWEEP_TEST_CAPTURE があれば AIJOBS_RUN とプロンプトを書き出す。"""
    stub = os.path.join(tmp, "stub_llm.py")
    open(stub, "w", encoding="utf-8").write(f"""#!/usr/bin/env python3
import sys, os, time, json
data = sys.stdin.read()
cap = os.environ.get("SWEEP_TEST_CAPTURE")
if cap:
    open(cap, "w").write(os.environ.get("AIJOBS_RUN", "") + "\\n" + data)
time.sleep({sleep})
print(json.dumps({verdicts!r}, ensure_ascii=False))
""")
    return f"{sys.executable} {stub}"


def run_sweep(env, apply=False):
    cmd = [sys.executable, SWEEP] + (["--apply"] if apply else [])
    return subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=90)


def read(p):
    return open(p, encoding="utf-8").read()


def key_count(*paths):
    return sum(read(p).count("<!-- s:") for p in paths if os.path.exists(p))


def mkrow(**kw):
    r = {"state": board.WAIT, "time": "10:00", "goal": "?", "now": "?", "repo": "?",
         "type": "実装", "who": "codex/?", "plan": "?", "key": "kkkk0000", "date": TODAY}
    r.update(kw)
    return r


# ---- dry-run: 板不変 ----

def test_dry_run_board_unchanged_and_verdicts_logged():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        p = write_board(goal, TODAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし"),
            wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?"),
        ])
        before = read(p)
        r = run_sweep(env)
        assert r.returncode == 0
        assert read(p) == before, "dry-run でボードが変わった"
        assert "s:aaaa0001 done" in r.stdout and "台帳:朝架電J列" in r.stdout
        assert "s:bbbb0002 unknown" in r.stdout        # LLM未設定 → unknown
        assert "dry-run" in r.stdout


def test_dry_run_does_not_create_board_files():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        r = run_sweep(env)
        assert r.returncode == 0
        assert "⏸行なし" in r.stdout
        found = [f for _, _, fs in os.walk(goal) for f in fs]
        assert found == [], "ボード未作成なのにファイルが生えた"


# ---- unknown: 両モードで無変更 ----

def test_unknown_rows_unchanged_in_both_modes():
    for apply in (False, True):
        with tempfile.TemporaryDirectory() as tmp:
            env, goal, tx = make_env(tmp)
            line = wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")
            p = write_board(goal, TODAY, [line])
            before = read(p)
            r = run_sweep(env, apply=apply)
            assert r.returncode == 0
            assert read(p) == before, f"unknown 行が変わった (apply={apply})"
            assert line in read(p)


# ---- apply: 台帳一致 finish＋[auto]根拠 ----

def test_apply_ledger_finish_with_auto_and_basis():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        unknown_line = wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")
        p = write_board(goal, TODAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし"),
            unknown_line,
        ])
        n_before = key_count(p)
        r = run_sweep(env, apply=True)
        text = read(p)
        assert r.returncode == 0
        assert "s:aaaa0001" not in text, "台帳一致行が finish で消えていない"
        assert "### 仕事" in text and "- 朝架電J列更新" in text
        assert re.search(r"^  - \d{2}:\d{2} .*\[auto\] 朝架電J列の定型更新を完了", text, re.M), \
            "時刻付きの [auto] 子entryが親配下に無い"
        assert "台帳:朝架電J列" in text, "子entryに根拠（台帳名）が無い"
        assert unknown_line in text, "unknown 行が変わった"
        assert key_count(p) == n_before - 1, "行数が finish 分だけ減っていない（増減異常）"


# ---- apply: codex one-shot完走 finish ----

def test_apply_oneshot_task_complete_finish():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        p = write_board(goal, TODAY, [
            wait_row("dddd0004", "one-shot作業", "実行", "RepoZ", "codex/codex", "なし"),
        ])
        make_rollout(tx, "dddd0004", age_min=120, complete=True)   # 沈黙120分 ≥ 閾値60分
        r = run_sweep(env, apply=True)
        text = read(p)
        assert r.returncode == 0
        assert "s:dddd0004" not in text
        assert "[auto] one-shot完走を確認" in text
        assert "task_complete" in text and "証跡:" in text, "子entryに証跡1行が無い"


def test_oneshot_not_silent_enough_stays():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        line = wait_row("dddd0004", "one-shot作業", "実行", "RepoZ", "codex/codex", "なし")
        p = write_board(goal, TODAY, [line])
        make_rollout(tx, "dddd0004", age_min=10, complete=True)    # 沈黙10分 < 閾値60分
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0
        assert read(p) == before, "沈黙不足の one-shot が流された"


def test_oneshot_incomplete_rollout_stays():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        line = wait_row("dddd0004", "one-shot作業", "実行", "RepoZ", "codex/codex", "なし")
        p = write_board(goal, TODAY, [line])
        make_rollout(tx, "dddd0004", age_min=120, complete=False)  # task_complete 無し
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0
        assert read(p) == before, "task_complete 無しの行が流された"


# ---- 計画列が実参照 → 自動対象外 ----

def test_plan_reference_excluded_from_apply_and_llm():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(
            tmp, ledger="## 全部一致\n- 一致: goal含む=作業\n- 確認: none\n- 記載: x\n- 判定: done\n")
        cap = os.path.join(tmp, "cap.txt")
        env["SWEEP_TEST_CAPTURE"] = cap
        env["SWEEP_LLM_CMD"] = make_llm_stub(tmp, {})
        plan_line = wait_row("cccc0003", "計画参照作業", "実装", "RepoY", "codex/gpt5",
                             "ai運用:デイリー運用刷新/05")
        llm_line = wait_row("eeee0005", "台帳外のなにか", "調査", "RepoY", "claude/?", "?")
        p = write_board(goal, TODAY, [plan_line, llm_line])
        make_rollout(tx, "cccc0003", age_min=180, complete=True)   # 完走証跡があっても対象外
        r = run_sweep(env, apply=True)
        text = read(p)
        assert r.returncode == 0
        assert plan_line in text, "計画列が実参照の行が変更された"
        assert "対象外" in r.stdout and "計画列が実参照" in r.stdout
        prompt = read(cap)
        assert "cccc0003" not in prompt, "計画参照行が LLM に送られた"
        assert "eeee0005" in prompt, "LLM 対象行がプロンプトに無い"


# ---- 失敗系: すべて exit 0・ボード無変更 ----

def test_llm_failure_exit0_board_unchanged():
    for apply in (False, True):
        with tempfile.TemporaryDirectory() as tmp:
            env, goal, tx = make_env(tmp, llm="exit 7")
            p = write_board(goal, TODAY, [
                wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")])
            before = read(p)
            r = run_sweep(env, apply=apply)
            assert r.returncode == 0, f"LLM失敗で exit {r.returncode}"
            assert read(p) == before
            assert "unknown" in r.stdout


def test_llm_timeout_exit0_board_unchanged():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp, extra={"SWEEP_LLM_TIMEOUT": "1"})
        env["SWEEP_LLM_CMD"] = make_llm_stub(tmp, {}, sleep=5)
        p = write_board(goal, TODAY, [
            wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")])
        before = read(p)
        r = run_sweep(env)
        assert r.returncode == 0, "LLMタイムアウトで exit != 0"
        assert read(p) == before
        assert "タイムアウト" in r.stdout


def test_llm_garbage_output_becomes_unknown():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp, llm="echo 'JSONではない出力'")
        p = write_board(goal, TODAY, [
            wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")])
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0
        assert read(p) == before
        assert "unknown" in r.stdout


def test_ledger_unreadable_exit0_board_unchanged():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        env["SWEEP_LEDGER"] = tmp   # ディレクトリを指す＝読込不可
        p = write_board(goal, TODAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし")])
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0, "台帳読込不可で exit != 0"
        assert read(p) == before
        assert "台帳読込不可" in r.stdout and "unknown" in r.stdout


# ---- 自己登録なし・AIJOBS_RUN 伝播 ----

def test_aijobs_run_propagates_to_llm_child():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        cap = os.path.join(tmp, "cap.txt")
        env["SWEEP_TEST_CAPTURE"] = cap
        env["SWEEP_LLM_CMD"] = make_llm_stub(tmp, {})
        write_board(goal, TODAY, [
            wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")])
        r = run_sweep(env)
        assert r.returncode == 0
        assert read(cap).split("\n")[0] == "1", "LLM子プロセスに AIJOBS_RUN=1 が伝播していない"


def test_sweep_never_increases_row_count():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        p_y = write_board(goal, YDAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし")])
        p_t = write_board(goal, TODAY, [
            wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")])
        n_before = key_count(p_y, p_t)
        run_sweep(env)                       # dry-run
        assert key_count(p_y, p_t) == n_before
        run_sweep(env, apply=True)           # apply（finish は行を減らす方向のみ）
        assert key_count(p_y, p_t) <= n_before, "sweep 後に行数が増えた"


# ---- 台帳ドラフト・LLM done は流さない ----

def test_draft_ledger_blocks_apply():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp, ledger=LEDGER_DRAFT)
        line = wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし")
        p = write_board(goal, TODAY, [line])
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0
        assert read(p) == before, "ドラフト台帳の一致行が流された"
        assert "ドラフト" in r.stdout


def test_llm_done_is_logged_but_never_applied():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        env["SWEEP_LLM_CMD"] = make_llm_stub(
            tmp, {"bbbb0002": {"verdict": "done", "basis": "LLMがそう思った"}})
        line = wait_row("bbbb0002", "謎の作業", "調査", "RepoX", "claude/?", "?")
        p = write_board(goal, TODAY, [line])
        before = read(p)
        r = run_sweep(env, apply=True)
        assert r.returncode == 0
        assert read(p) == before, "LLM done が流し込まれた（適格条件外）"
        assert "s:bbbb0002 done" in r.stdout and "LLM:" in r.stdout


# ---- 上限・前日ボード ----

def test_apply_cap_limits_finishes():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp, extra={"SWEEP_APPLY_MAX": "1"})
        p = write_board(goal, TODAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし"),
            wait_row("aaab0002", "朝架電J列再確認", "J列確認", "仕事", "codex/gpt5", "なし", t="10:05"),
        ])
        r = run_sweep(env, apply=True)
        text = read(p)
        assert r.returncode == 0
        assert text.count("<!-- s:") == 1, "上限1件なのに2件 finish された"
        assert "上限 1 件に到達" in r.stdout


def test_yesterday_board_swept_and_closed_in_place():
    with tempfile.TemporaryDirectory() as tmp:
        env, goal, tx = make_env(tmp)
        p_y = write_board(goal, YDAY, [
            wait_row("aaaa0001", "朝架電J列更新", "J列確認", "仕事", "codex/gpt5", "なし")])
        r = run_sweep(env, apply=True)
        text_y = read(p_y)
        assert r.returncode == 0
        assert f"[{YDAY}] s:aaaa0001" in r.stdout
        assert "s:aaaa0001" not in text_y, "前日⏸行が finish されていない"
        assert "[auto]" in text_y, "前日板の「終わったこと」に [auto] 子が無い"
        p_t = sweep_mod.board_path(TODAY)
        assert not os.path.exists(p_t.replace(TODAY + ".md", "")) or "[auto]" not in (
            read(p_t) if os.path.exists(p_t) else ""), "前日行の成果が当日板へ漏れた"


# ---- コードパス検証: 版管理操作なし ----

def test_source_has_no_vcs_calls():
    src = read(SWEEP)
    assert not re.search(r"\bgit\b", src, re.IGNORECASE), "sweep.py に版管理系の記述がある"


# ---- 単体: 一致条件・台帳パース・task_complete ----

def test_match_cond_unit():
    mc = sweep_mod.match_cond
    row = mkrow(goal="関東印刷更新", now="印刷確認", who="codex/gpt5",
                repo="/Users/x/projects/active/仕事")
    assert mc("repo=仕事; goal含む=印刷更新", row, True)          # basename一致＋含む
    assert not mc("repo=仕事; goal前方一致=印刷更新", row, True)  # 前方一致は接頭語で外れる
    assert mc("who=codex", row, True) and not mc("who=claude", row, True)
    assert mc("now前方一致=# Overview|印刷", row, True)            # OR
    assert not mc("実体=なし", row, True) and mc("実体=なし", row, False)
    assert not mc("", row, True), "空条件が全行一致になっている"
    assert not mc("未知キー=x", row, True), "未知キーが素通しになっている"


def test_parse_ledger_unit():
    entries = sweep_mod.parse_ledger(LEDGER_DRAFT)
    assert len(entries) == 1
    e = entries[0]
    assert e["name"] == "朝架電J列" and e["draft"] is True
    for k in ("一致", "終わり", "確認", "記載", "判定"):
        assert k in e, f"キー {k} が読めていない"
    assert sweep_mod.parse_ledger(LEDGER_OK)[0]["draft"] is False
    assert sweep_mod.parse_ledger("## 名前だけ\n- 記載: x\n") == []   # 一致なしは無視


def test_codex_task_complete_unit():
    with tempfile.TemporaryDirectory() as tmp:
        p1 = make_rollout(tmp, "keyx0001", complete=True)
        done, last = sweep_mod.codex_task_complete(p1)
        assert done and last == "完了しました"
        p2 = make_rollout(tmp, "keyx0002", complete=False)
        assert sweep_mod.codex_task_complete(p2) == (False, None)


def test_shipped_ledger_parses_all_draft_and_matches_focusmap():
    real = os.path.join(sweep_mod.board_dir(), "routine-ledger.md")
    entries = sweep_mod.parse_ledger(read(real))
    names = {e["name"] for e in entries}
    assert {"架電", "印刷", "focusmap定期"} <= names  # 2026-07-09 カテゴリ名へリネーム（人間要望）
    assert all(e["draft"] for e in entries), "初期エントリにドラフト明記が無い"
    row = mkrow(goal="?", now="# Overview Generate 0 to", repo="?", who="codex/?")
    m = sweep_mod.match_ledger(entries, row, has_tx=False)
    assert m and m["name"] == "focusmap定期"
    assert sweep_mod.match_ledger(entries, row, has_tx=True) is None  # 実体ありは不一致


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items())
           if k.startswith("test_") and callable(v)]
    passed = failed = 0
    for fn in fns:
        try:
            fn()
            passed += 1
            print("PASS:", fn.__name__)
        except AssertionError as e:
            failed += 1
            print("FAIL:", fn.__name__, "--", e)
        except Exception as e:
            failed += 1
            print("ERROR:", fn.__name__, "--", f"{e.__class__.__name__}: {e}")
    print(f"\n== 結果: PASS={passed} FAIL={failed} ==")
    sys.exit(1 if failed else 0)
