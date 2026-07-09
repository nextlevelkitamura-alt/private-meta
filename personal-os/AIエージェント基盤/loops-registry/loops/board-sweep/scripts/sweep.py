#!/usr/bin/env python3
# board-sweep — ⏸（停止・確認待ち）行の自動判定sweep（dry-run既定・板無変更）。
#
# 設計（デイリー運用刷新 子05・2026-07-09 / 実装契約-第1波 §5-§7）:
#   - 当日＋前日ボードの⏸行を列挙（board.py を import して parse_line 等を再利用。board.py 本体は不可侵）。
#   - 実体transcript照合: Claude=~/.claude/projects/**.jsonl／Codex=~/.codex/sessions/**/rollout-*.jsonl
#     （探索根は SESSION_BOARD_TX_ROOTS で差替可・board._tx_roots と共通）。codex は末尾の task_complete を機械確認。
#   - 定型台帳マッチ: hooks-registry/hooks/session-board/routine-ledger.md（SWEEP_LEDGER で差替可）。
#   - headless LLM判定: 残り行をまとめて1回（SWEEP_LLM_CMD・stdin=プロンプト/stdout=JSON。テストはstub）。
#   - 既定は dry-run: 判定（done/not-done/unknown＋根拠）をログに書くだけでボード無変更。
#   - --apply: 適格行のみ board.py finish を subprocess で実行。適格＝①台帳一致（判定=done・確認OK・非ドラフト・
#     実体があれば沈黙 SWEEP_LEDGER_SILENCE_MIN 分以上）②codex one-shot完走（task_complete＋沈黙 SWEEP_SILENCE_MIN 分以上）。
#     LLM の done は流し込まない（分類ログ用）。上限 SWEEP_APPLY_MAX 件/回。子entryは [auto]＋根拠必須。
#   - 計画列が実参照（?/なし 以外）の行は自動対象外。unknown は行を1バイトも変えない。
#   - 失敗（LLM失敗・タイムアウト・台帳パース失敗・内部例外）はすべて exit 0 でボード無変更（ログのみ）。
#   - 版管理系の操作はコードパスごと持たない（テストがソースを機械検証する）。
import os

# 自己登録ガード: このプロセスと全子プロセス（headless LLM 含む）で session-board フックを無効化。
# 受け口 common.load_input() は AIJOBS_RUN 非空で None を返すため、sweep 起因の行がボードに増えない。
os.environ.setdefault("AIJOBS_RUN", "1")

import argparse      # noqa: E402
import datetime      # noqa: E402
import json          # noqa: E402
import re            # noqa: E402
import subprocess    # noqa: E402
import sys           # noqa: E402
import time          # noqa: E402


def board_dir():
    """session-board 共有本体（board.py・routine-ledger.md）の場所。SWEEP_BOARD_DIR で差替可。
    既定はこのファイルの実体位置からの相対解決（worktree でもそのまま動く）。"""
    env = os.environ.get("SWEEP_BOARD_DIR")
    if env:
        return env
    here = os.path.dirname(os.path.realpath(__file__))
    # loops-registry/loops/board-sweep/scripts → AIエージェント基盤 → hooks-registry/hooks/session-board
    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(here))))
    return os.path.join(base, "hooks-registry", "hooks", "session-board")


sys.path.insert(0, board_dir())
import board  # noqa: E402  session-board のエンジンを読み取り専用で再利用（本体は変更しない）

BOARD_PY = os.path.join(board_dir(), "board.py")
VERDICTS = ("done", "not-done", "unknown")


def _int_env(name, default):
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


def _clean1(s):
    """ログ・entry 用の1行化（列区切りを壊す文字の無害化。board.clean と同方針）。"""
    return re.sub(r"\s+", " ", s or "").replace("|", "｜").strip()


# ---- ⏸行の列挙（読み取り専用） ----

def today_str():
    return os.environ.get("SESSION_BOARD_DATE") or datetime.datetime.now().strftime("%Y-%m-%d")


def yesterday_str(today):
    d = datetime.date.fromisoformat(today) - datetime.timedelta(days=1)
    return d.isoformat()


def board_path(date_s):
    """board.daily_path と同じ規約（GOAL_BASE/<年>/<月>/<日>.md）を日付指定で解決。"""
    base = os.environ.get("GOAL_BASE") or os.path.expanduser(
        "~/Private/personal-os/my-brain/ゴール/デイリー")
    y, m, _ = date_s.split("-")
    return os.path.join(base, y, m, f"{date_s}.md")


def list_wait_rows(date_s):
    """date_s のボードから⏸行を dict（board.parse_line＋date）で列挙。ボードが無ければ空。"""
    path = board_path(date_s)
    if not os.path.exists(path):
        return []
    lines = open(path, encoding="utf-8").read().split("\n")
    s, e = board.section_bounds(lines, board.AGENTS_H)
    if s is None:
        return []
    rows = []
    for j in range(s + 1, e):
        r = board.parse_line(lines[j])
        if r and r["state"] == board.WAIT:
            r["date"] = date_s
            rows.append(r)
    return rows


# ---- 定型台帳（routine-ledger.md） ----

def ledger_path():
    return os.environ.get("SWEEP_LEDGER") or os.path.join(board_dir(), "routine-ledger.md")


def parse_ledger(text):
    """1定型=1節（## 名前）・キー5つ（- 一致/終わり/確認/記載/判定:）を dict のリストに。
    節内に「ドラフト」の語があれば draft=True（自動finishしない・ログのみ）。一致キーの無い節は無視。"""
    entries, cur = [], None
    for ln in text.split("\n"):
        m = re.match(r"^## (.+?)\s*$", ln)
        if m:
            cur = {"name": m.group(1), "body": []}
            entries.append(cur)
            continue
        if cur is None:
            continue
        cur["body"].append(ln)
        m = re.match(r"^- (一致|終わり|確認|記載|判定):\s*(.*)$", ln)
        if m:
            cur[m.group(1)] = m.group(2).strip()
    out = []
    for e in entries:
        if not e.get("一致"):
            continue
        e["draft"] = any("ドラフト" in ln for ln in e["body"])
        out.append(e)
    return out


def load_ledger():
    """(entries, 注記) を返す。読込・パース失敗は空台帳＋注記（exit 0 無害の一部）。"""
    path = ledger_path()
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as e:
        return [], f"台帳読込不可({e.__class__.__name__})"
    try:
        return parse_ledger(text), None
    except Exception as e:
        return [], f"台帳パース失敗({e.__class__.__name__})"


def _repo_norm(v):
    return os.path.basename((v or "").rstrip("/")) or (v or "")


def match_cond(cond, row, has_tx):
    """一致条件 'キー=値; キー=値' を全て AND 評価。値内の '|' は OR（いずれか一致）。
    使えるキー: repo（basename一致）/ who（runtime または runtime/model 前方一致）/
    goal前方一致 / goal含む / now前方一致 / 実体（なし|あり）。
    空条件・未知キーは安全側＝不一致（全行一致の事故を防ぐ）。"""
    parts = [p.strip() for p in (cond or "").split(";") if p.strip()]
    if not parts:
        return False
    for part in parts:
        if "=" not in part:
            return False
        k, v = part.split("=", 1)
        k, v = k.strip(), v.strip()
        alts = [a for a in v.split("|") if a]
        if k == "repo":
            if _repo_norm(row.get("repo")) not in [_repo_norm(a) for a in alts]:
                return False
        elif k == "who":
            who = row.get("who") or ""
            if not any(who == a or who.startswith(a + "/") for a in alts):
                return False
        elif k == "goal前方一致":
            if not any((row.get("goal") or "").startswith(a) for a in alts):
                return False
        elif k == "goal含む":
            if not any(a in (row.get("goal") or "") for a in alts):
                return False
        elif k == "now前方一致":
            if not any((row.get("now") or "").startswith(a) for a in alts):
                return False
        elif k == "実体":
            if v == "なし" and has_tx:
                return False
            if v == "あり" and not has_tx:
                return False
            if v not in ("なし", "あり"):
                return False
        else:
            return False
    return True


def match_ledger(entries, row, has_tx):
    for e in entries:
        if match_cond(e.get("一致", ""), row, has_tx):
            return e
    return None


def run_check(spec):
    """台帳の 確認 キー（読み取り専用の実体確認）。OK=True。
    none=確認なしでOK / file:<パス>・log:<パス>=存在でOK / cmd:<コマンド>=exit 0 でOK（timeout付き）。"""
    spec = (spec or "none").strip()
    if spec in ("", "none"):
        return True
    if spec.startswith("file:") or spec.startswith("log:"):
        return os.path.exists(os.path.expanduser(spec.split(":", 1)[1].strip()))
    if spec.startswith("cmd:"):
        try:
            r = subprocess.run(["/bin/sh", "-c", spec[4:].strip()],
                               capture_output=True, timeout=20)
            return r.returncode == 0
        except Exception:
            return False
    return False


# ---- 実体transcript証跡 ----

def codex_task_complete(path):
    """codex rollout の末尾レコード（最大10件）に task_complete があるか。
    (完走bool, 最終応答|None)。読み失敗は (False, None)。"""
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 65536))
            tail = f.read().decode("utf-8", errors="replace")
    except OSError:
        return False, None
    recs = [ln for ln in tail.split("\n") if ln.strip()][-10:]
    for ln in reversed(recs):
        try:
            d = json.loads(ln)
        except ValueError:
            continue
        p = d.get("payload")
        if isinstance(p, dict) and p.get("type") == "task_complete":
            msg = p.get("last_agent_message")
            return True, (str(msg) if msg else None)
    return False, None


def evidence(key, files):
    """(最新transcript|None, 沈黙分|None, codex完走bool, 最終応答|None)。"""
    f = board._newest_for(key, files)
    if f is None:
        return None, None, False, None
    try:
        silent = (time.time() - os.path.getmtime(f)) / 60.0
    except OSError:
        return None, None, False, None
    completed, last = (False, None)
    if os.path.basename(f).startswith("rollout-"):
        completed, last = codex_task_complete(f)
    return f, silent, completed, last


# ---- headless LLM判定（1sweepでまとめて1回） ----

def build_prompt(ctx):
    lines = [
        "あなたはセッションボードの掃除係。以下は当日/前日デイリーボードの⏸（停止・確認待ち）行。",
        "各行が「実際に終わっているか」を done / not-done / unknown の3値で判定し、根拠を1行で付けよ。",
        "確信できないものは必ず unknown（unknown は安全・誤 done は事故）。",
        '出力は次の JSON オブジェクトのみ（説明文・コードフェンス不要）: '
        '{"<key>": {"verdict": "done|not-done|unknown", "basis": "<根拠1行>"}}',
        "行:",
    ]
    for row, f, silent, completed, last in ctx:
        ev = f"実体あり・沈黙{int(silent)}分" if f else "実体なし"
        if completed:
            ev += "・末尾task_complete"
        item = (f"- key={row['key']} date={row['date']} goal={row['goal']} 今={row['now']} "
                f"repo={row['repo']} 種別={row['type']} 誰={row['who']} 証跡={ev}")
        if last:
            item += f" 最終応答=「{_clean1(last)[:200]}」"
        lines.append(item)
    return "\n".join(lines)


def parse_llm_json(out):
    """stdout から JSON オブジェクトを1つ取り出す（フェンス・前置きに耐える）。失敗は ({}, 注記)。"""
    m = re.search(r"\{.*\}", out, re.DOTALL)
    if not m:
        return {}, "LLM出力にJSONなし"
    try:
        d = json.loads(m.group(0))
    except ValueError:
        return {}, "LLM出力のJSONパース失敗"
    if not isinstance(d, dict):
        return {}, "LLM出力がオブジェクトでない"
    return d, None


def llm_judge(ctx):
    """残り行をまとめて1回だけ判定。(judgments dict, 注記)。失敗は ({}, 注記)＝呼び出し側で unknown。"""
    cmd = (os.environ.get("SWEEP_LLM_CMD") or "").strip()
    if not cmd:
        return {}, "LLM未設定(SWEEP_LLM_CMD)"
    prompt = build_prompt(ctx)
    try:
        r = subprocess.run(["/bin/sh", "-c", cmd], input=prompt, capture_output=True,
                           text=True, timeout=_int_env("SWEEP_LLM_TIMEOUT", 180))
    except subprocess.TimeoutExpired:
        return {}, "LLMタイムアウト"
    except Exception as e:
        return {}, f"LLM実行失敗({e.__class__.__name__})"
    if r.returncode != 0:
        return {}, f"LLM exit={r.returncode}"
    return parse_llm_json(r.stdout)


# ---- 本体 ----

def _res(row, verdict, basis, eligible, entry=None):
    return {"row": row, "verdict": verdict, "basis": _clean1(basis),
            "eligible": eligible, "entry": _clean1(entry or "")}


def judge_rows(rows):
    """全⏸行を判定して {(date,key): result} を返す。ボードへは一切書かない（純関数に近い読み取りのみ）。"""
    ledger, ledger_note = load_ledger()
    files = board._list_transcripts()
    silence_min = _int_env("SWEEP_SILENCE_MIN", 120)
    ledger_silence_min = _int_env("SWEEP_LEDGER_SILENCE_MIN", 30)
    res, llm_ctx = {}, []
    for row in rows:
        k = (row["date"], row["key"])
        f, silent, completed, last = evidence(row["key"], files)
        plan = row.get("plan") or board.PLACEHOLDER
        if plan not in (board.PLACEHOLDER, "なし"):
            res[k] = _res(row, "対象外", "計画列が実参照", False)
            continue
        led = match_ledger(ledger, row, has_tx=f is not None)
        if led:
            name = led["name"]
            if (led.get("判定") or "").strip() != "done":
                res[k] = _res(row, "unknown", f"台帳:{name}（判定≠done）", False)
            elif not run_check(led.get("確認")):
                res[k] = _res(row, "unknown", f"台帳:{name} 一致・確認NG", False)
            elif f is not None and silent < ledger_silence_min:
                res[k] = _res(row, "unknown",
                              f"台帳:{name} 一致・沈黙{int(silent)}分<{ledger_silence_min}分", False)
            elif led.get("draft"):
                res[k] = _res(row, "done", f"台帳:{name}（ドラフト・流し込み不可）", False)
            else:
                res[k] = _res(row, "done", f"台帳:{name}", True,
                              entry=led.get("記載") or "定型作業を完了")
            continue
        if completed and silent is not None and silent >= silence_min:
            basis = f"証跡:{os.path.basename(f)} 末尾task_complete・沈黙{int(silent)}分"
            res[k] = _res(row, "done", basis, True, entry="one-shot完走を確認")
            continue
        llm_ctx.append((row, f, silent, completed, last))
    note = ledger_note
    if llm_ctx:
        judgments, err = llm_judge(llm_ctx)
        for row, f, silent, completed, last in llm_ctx:
            k = (row["date"], row["key"])
            j = judgments.get(row["key"])
            if isinstance(j, dict) and j.get("verdict") in VERDICTS:
                res[k] = _res(row, j["verdict"], "LLM: " + (str(j.get("basis") or "根拠なし")), False)
            else:
                res[k] = _res(row, "unknown", err or "LLM判定なし", False)
    return res, note


def apply_finish(row, result):
    """適格行1件を board.py finish（subprocess）で「終わったこと」へ。成功=True。
    行の属する日付のボードに閉じる（SESSION_BOARD_DATE を行の date に固定＝前日⏸も前日板で解決）。"""
    parent = row["goal"] if row["goal"] != board.PLACEHOLDER else (
        row["now"] if row["now"] != board.PLACEHOLDER else "無題セッション")
    entry = f"[auto] {result['entry'] or '完了'} ｜根拠: {result['basis']}"
    env = dict(os.environ)
    env["SESSION_BOARD_DATE"] = row["date"]
    try:
        r = subprocess.run(
            [sys.executable, BOARD_PY, "finish", "--key", row["key"],
             "--repo", row["repo"], "--parent", parent, "--entry", entry],
            capture_output=True, text=True, env=env, timeout=30)
        return r.returncode == 0, entry
    except Exception:
        return False, entry


def sweep(apply):
    today = today_str()
    yday = yesterday_str(today)
    rows = list_wait_rows(yday) + list_wait_rows(today)
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    mode = "APPLY" if apply else "DRY-RUN"
    print(f"[board-sweep] {ts} {mode} 対象: {yday}＋{today} ⏸{len(rows)}行")
    if not rows:
        print("  ⏸行なし")
        return
    res, note = judge_rows(rows)
    if note:
        print(f"  注記: {note}")
    counts = {}
    for row in rows:
        r = res[(row["date"], row["key"])]
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
        flag = "◎" if r["eligible"] else " "
        print(f"  {flag}[{row['date']}] s:{row['key']} {r['verdict']} ｜根拠: {r['basis']} "
              f"｜goal: {_clean1(row['goal'])[:30]}")
    summary = " ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    eligible_n = sum(1 for r in res.values() if r["eligible"])
    print(f"  集計: {summary} ｜自動finish適格: {eligible_n}件（◎）")
    if not apply:
        print("  （dry-run: ボードは無変更。流し込みは --apply）")
        return
    apply_max = _int_env("SWEEP_APPLY_MAX", 3)
    applied = 0
    for row in rows:
        r = res[(row["date"], row["key"])]
        if not r["eligible"]:
            continue
        if applied >= apply_max:
            print(f"  自動finish上限 {apply_max} 件に到達・残りは次回")
            break
        ok, entry = apply_finish(row, r)
        if ok:
            applied += 1
            print(f"  finish: [{row['date']}] s:{row['key']} ← {entry}")
        else:
            print(f"  finish失敗（無害・行は残る）: s:{row['key']}")
    print(f"  finish実行: {applied}/{eligible_n}件（上限{apply_max}）")


def main():
    ap = argparse.ArgumentParser(
        description="⏸停止行の自動判定sweep（既定dry-run＝ボード無変更・判定ログのみ）")
    ap.add_argument("--apply", action="store_true",
                    help="適格行（台帳一致 or one-shot完走）のみ board.py finish で流し込む")
    args = ap.parse_args()
    try:
        sweep(args.apply)
    except Exception as e:
        # どんな内部失敗でも exit 0（loopログにのみ残す・ボードとセッションを壊さない）
        print(f"[board-sweep] 内部エラー（exit 0・無害）: {e.__class__.__name__}: {e}",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
