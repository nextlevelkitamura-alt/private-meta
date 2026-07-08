#!/usr/bin/env python3
# session-board 受け口の共通ロジック（Claude / Codex 両受け口が import する）。
# 実体は hooks-registry/hooks/session-board/common.py（runtime非依存の共有本体）。
# 受け口（claude/・codex/ の各 .py）は realpath で自分の実体を解決し、ここを import する。
#
# 役割分担（2026-07-08 再設計・Python=枠と機械処理／AI=意味づけ）:
#   SessionStart     = start_register(): 生存照合＋キー通知1行のみ（枠登録はしない＝初回プロンプトへ一本化・幽霊枠掃除）
#   UserPromptSubmit = register_prompt(): 枠登録（初回・主経路）／⏸→🟢復帰／「今」初回仮置き＋二段注入
#                      （目標未記入=フルガイド／記入済み=2〜3行ミラー）のテキストを返す
#   Stop             = stop_flip(): run→⏸＋reconcile
# 受け口は返ったテキストを runtime の契約（Claude=plain stdout / Codex=JSON）で出すだけ。
import json
import os
import re
import subprocess
import sys

# common.py 自身の実体ディレクトリ＝共有本体（board.py・手順md）の置き場。
CORE_DIR = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(CORE_DIR, "board.py")
PLACEHOLDER = "?"
TYPES = "計画|実装|リサーチ|レビュー|その他"
# 種別の一言定義（詳細・境界例の正本は README.md。ここは注入用の最小コピー）
TYPE_DEFS = ("種別: 計画=進め方を決め文書化／実装=変更して動かす／リサーチ=調べてまとめる（何も変えない）／"
             "レビュー=評価して指摘（自分で直さない）／迷ったら その他（後で update で直すのが正常）")


def load_input():
    """stdin の JSON を返す。非対話（AIJOBS_RUN）・不正JSONは None。"""
    if os.environ.get("AIJOBS_RUN"):
        return None
    try:
        return json.load(sys.stdin)
    except Exception:
        return None


def session_key(d):
    """対話セッションのキー（sid 先頭8字）。未取得・subagent（agent-*）は None。"""
    sid = d.get("session_id") or d.get("sessionId") or ""
    if not sid or sid.startswith("agent-"):
        return None
    return sid[:8]


def is_subagent(d):
    """transcript が */subagents/* ならサブエージェント経路。"""
    tp = d.get("transcript_path") or d.get("transcriptPath") or ""
    return "/subagents/" in tp


def repo_of(cwd):
    """cwd の git トップ basename（無ければ cwd の basename）。"""
    if not cwd:
        return ""
    r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return os.path.basename(r.stdout.strip()) if r.returncode == 0 else os.path.basename(cwd)


# ---- board.py 呼び出し（すべて非ブロッキング・失敗は無視） ----

def board_check(key):
    return subprocess.run([BOARD, "check", "--key", key],
                          capture_output=True, text=True).stdout.strip()


def board_show(key):
    """行の中身を dict で（state/goal/now/type/repo/who/plan）。無ければ None。"""
    out = subprocess.run([BOARD, "show", "--key", key],
                         capture_output=True, text=True).stdout.rstrip("\n")
    if not out or out == "missing":
        return None
    parts = out.split("\t")
    if len(parts) < 6:
        return None
    return dict(zip(("state", "goal", "now", "type", "repo", "who", "plan"), parts))


def board_goals():
    """現在ボードにある目標の一覧（重複なし・未記入除外）。"""
    out = subprocess.run([BOARD, "goals"], capture_output=True, text=True).stdout
    return [g for g in out.splitlines() if g.strip()]


def board_add(key, repo, who):
    subprocess.run([BOARD, "add", "--key", key, "--repo", repo or "?", "--who", who],
                   capture_output=True)


def board_update(key, **kw):
    cmd = [BOARD, "update", "--key", key]
    for k, v in kw.items():
        cmd += [f"--{k}", v]
    subprocess.run(cmd, capture_output=True)


def board_flip(key, state):
    subprocess.run([BOARD, "flip", "--key", key, "--state", state], capture_output=True)


def board_reconcile():
    """🟢/🔵を実体トランスクリプトで照合し沈黙行を⏸へ＋整列（board.py reconcile）。
    掃除は start-latency に乗らない経路（Stop / SessionStart）からのみ呼ぶ。失敗は無視。"""
    subprocess.run([BOARD, "reconcile"], capture_output=True)


# ---- hook 本体 ----

def start_register(d, runtime):
    """SessionStart 共通: 生存照合＋キー通知1行のみ（枠登録はしない・注入テキストを返す。対象外は None）。
    枠登録は初回プロンプト時（register_prompt の保険 add）へ一本化した（2026-07-08 幽霊枠掃除）。
    プロンプトを持たない/ガードで弾かれる補助セッションは枠が載らなくなる。意味づけは AI が後で update する。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return None
    repo = repo_of(d.get("cwd") or "")
    board_reconcile()
    return (f"[session-board] ボードキー s:{key}（{repo or '?'}）。"
            "行は最初のプロンプト時に登録される。依頼を理解したら "
            "update で目標・種別・今・モデルを正す（手順もその時に注入）。")


def _summarize(prompt):
    return re.sub(r"\s+", " ", prompt).replace("|", "／").replace("<", "＜").replace(">", "＞")[:24]


def _first_guide(key, repo, runtime):
    """初回注入（目標が未記入の間）: 記入コマンド・種別/計画列定義・既存目標一覧・既存計画確認・計画3判定。"""
    goals = board_goals()
    lines = [
        f"[session-board] s:{key} | {repo or '?'} | {runtime}",
        "最初の依頼を理解したら、ボード行を正す（Bash 1コマンド・このセッションで1回）:",
        f"  {BOARD} update --key {key} --type <{TYPES}> "
        "--goal \"<達成したらこのセッションを閉じられる1行・30字以内>\" "
        "--now \"<いま着手する一歩・20字以内>\" --model <自分のモデル名（小文字短縮 例: fable5）> "
        "--plan \"<企画名[/NN] か なし>\"",
        TYPE_DEFS,
        "計画列: 計画=これから置く先／実装・レビュー=拠り所の計画／リサーチ=任意。"
        "①1〜2ファイル ②容易に戻せる ③人間ゲート無し の全YESなら --plan なし でよい（運用契約§2のサクッと）。",
    ]
    if goals:
        lines += [
            "いま動いている他の目標: " + "／".join(f"「{g}」" for g in goals[:6]),
            "  → 自分の依頼がどれかと同じ目的なら、その文言をそのまま --goal にコピーして合流"
            "（親名=目標名で成果が1つの親に集まる）。無関係なら新しい目標を立てる。",
        ]
    lines += [
        "置く前に ls <repo>/plans/{planning,active} で既存計画・親programを確認（重複新設しない）。",
        "計画種別なら、置く前に3判定（詳細: 運用契約§2・areas/AGENTS.md §3）:",
        " ①規模: ①1〜2ファイル ②容易に戻せる ③人間ゲート無し が全YES=サクッと → "
        "計画ファイル不要（--plan なし・ボードとlogで足りる）。1つでもNOなら plan.md 必須。",
        " ②形: 独立に完了する子計画を2本以上生む → program化（program.md＋plans/NN-子.md）。"
        "それ以外は単発 plan.md。",
        " ③完了条件: レビュー項目（「こうなっていれば正しい」形式・対象明示）を書いてから着手。"
        "雛形: plan-ops new-plan.sh",
        " 置き場: repo概要.md で所属repoを判定（cwdでなく依頼の中身で）→ そのrepo AGENTS.md → "
        "<repo>/plans/。決めたら update --plan で宣言。",
        f"節目: {BOARD} log --key {key} --repo <repo> --parent <目標名> --entry <成果1行>"
        "（時刻・所要は自動付与）。サブエージェント起動中: flip --state sub／復帰: flip --state run。"
        f"完了は人間確認後に finish。詳細: {os.path.join(CORE_DIR, 'session-start.md')}",
    ]
    return "\n".join(lines)


def _mirror(key, row):
    """2回目以降の注入（毎プロンプト・最小2〜3行）: 行のミラー＋ズレ回収の催促。
    3行目は優先順で出し分け（種別=計画 ＞ 計画:? 催促 ＞ 2行のみ）。両該当は計画3判定のみ。"""
    plan = row.get("plan") or PLACEHOLDER
    lines = [
        f"[session-board] 目標:{row['goal']} | 今:{row['now']} | 種別:{row['type']} | 計画:{plan}",
        f"→ 実態とズレていたら {BOARD} update --key {key} --now \"<今の一歩>\""
        "（目標・種別・計画が変われば --goal/--type/--plan も）。節目なら log。",
    ]
    if row.get("type") == "計画":
        lines.append("計画3判定: ①サクッと（3条件全YES）→ --plan なし ②子2本以上→program化 "
                     "③レビュー項目を書いてから着手 → 置き場: repo概要.md→<repo>/plans/"
                     "（運用契約§2・areas§3）。")
    elif plan == PLACEHOLDER:
        lines.append("計画:? → 拠り所（実装・レビュー）/置き先（計画）を update --plan で。"
                     "①1〜2ファイル②容易に戻せる③人間ゲート無し 全YESなら --plan なし。")
    return "\n".join(lines)


def register_prompt(d, runtime):
    """UserPromptSubmit 共通: 未登録→枠登録（初回プロンプトで枠を作る主経路・2026-07-08）／⏸→🟢復帰／
    「今」が未記入なら先頭24字を初回だけ仮置き（以降 Python は「今」を上書きしない）。
    注入テキストを返す（subagent／スラッシュ／空・添付のみ は None）。🔵(sub) は触らない。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return None
    prompt = d.get("prompt") or ""
    p = prompt.strip() if isinstance(prompt, str) else ""
    if not p or p.startswith("/") or p.startswith("<"):
        return None
    repo = repo_of(d.get("cwd") or "")
    row = board_show(key)
    if row is None:
        board_add(key, repo, f"{runtime}/{PLACEHOLDER}")
        row = board_show(key) or {"state": "run", "goal": PLACEHOLDER, "now": PLACEHOLDER,
                                  "type": "その他", "repo": repo or "?",
                                  "who": f"{runtime}/{PLACEHOLDER}", "plan": PLACEHOLDER}
    if row["state"] == "wait":
        board_flip(key, "run")
    if row["now"] == PLACEHOLDER:      # 初回だけの仮置き（枠を空にしない）。意味づけはAIの update --now
        board_update(key, now=_summarize(p))
        row["now"] = _summarize(p)
    if row["goal"] == PLACEHOLDER:
        return _first_guide(key, row.get("repo") or repo, runtime)
    return _mirror(key, row)


def stop_flip(d):
    """Stop 共通: run のときだけ⏸(wait)へ。sub／wait／missing は触らない。ブロックしない。
    併せてボード全体を生存照合＋整列（Stop=ターン終了なので開始レイテンシに無関係）。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return
    if board_check(key) == "run":
        board_flip(key, "wait")
    board_reconcile()
