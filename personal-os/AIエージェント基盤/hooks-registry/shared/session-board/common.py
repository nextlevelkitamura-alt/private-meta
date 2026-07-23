#!/usr/bin/env python3
# session-board 受け口の共通ロジック（Claude / Codex 両受け口が import する）。
# 実体は hooks-registry/shared/session-board/common.py（runtime非依存の共有本体）。
# イベント本体（events/ の各 .py）は realpath で自分の実体を解決し、ここを import する。
#
# 役割分担（2026-07-08 再設計・Python=枠と機械処理／AI=意味づけ）:
#   SessionStart     = start_register(): repo実行Context記録＋生存照合＋キー通知＋固定分類policy（session枠登録はしない）
#   UserPromptSubmit = register_prompt(): repo Context自己修復→turn pending→枠登録／⏸→🟢復帰→短い動的分類packet
#                      （目標未記入=フルガイド／記入済み=2〜3行ミラー）を1本文で返す
#   Stop             = stop_flip(): run→⏸＋reconcile
# 受け口は返ったテキストを runtime の契約（Claude=plain stdout / Codex=JSON）で出すだけ。
import json
import hashlib
import os
import re
import subprocess
import sys
import time
import uuid

from sanitize import sanitize_text

# common.py 自身の実体ディレクトリ＝共有本体（board.py・手順md）の置き場。
CORE_DIR = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(CORE_DIR, "board.py")
POLICY_FILE = os.path.join(os.path.dirname(os.path.dirname(CORE_DIR)), "events", "prompt-register", "session-classification-policy.md")
PLACEHOLDER = "?"
TYPES = "計画|実装|リサーチ|レビュー|その他"
# 種別の一言定義（詳細・境界例の正本は events/session-start/AGENTS.md。ここは注入用の最小コピー）
TYPE_DEFS = ("種別: 計画=進め方を決め文書化／実装=変更して動かす／リサーチ=調べてまとめる（何も変えない）／"
             "レビュー=評価して指摘（自分で直さない）／迷ったら その他（後で update で直すのが正常）")

# 2026-07-15 子04で用意したPrompt Submit本文。2026-07-16の承認セット承認により有効化し、
# _first_guide がこの本文を初回注入へ含める（ミラーはレビュー宣言の1行のみ）。
# 本文の唯一の生成元を common.py に保ち、runtime別シムへ複製しない。
def plan_create_review_guide_candidate():
    return (
        "計画入口: サクッと3条件（1〜2ファイル・容易に戻せる・目的と完了条件が明確）が全YESでない、"
        "または不明なら plan-create-review。既存計画を確認し、なければ対象repo最寄りAGENTS.mdが宣言する"
        "計画箱へ起案する。hookはrepo・計画箱・レビュー合否・バケット遷移を決めない。\n"
        "状態は planning→active→done→archive。指揮官がactive化し、最終評価全PASSでdone、"
        "archiveは人間の明示確認だけで行う。容量は active=4／paused=3／done=8（planning・archiveは無制限）で、"
        "事実確認は bucketctl check。満杯でも自動退避しない。\n"
        "子のレビュー宣言を確認: 一括は束ねて実施し、後続が成果を直接使う子だけ都度レビュー。"
        "finishはsession-boardの記録を閉じるだけで、archiveの承認・実行ではない。"
    )


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


def _routing():
    if CORE_DIR not in sys.path:
        sys.path.insert(0, CORE_DIR)
    import routing
    return routing


def _execution_context(cwd, runtime):
    try:
        return _routing().resolve_execution_context(cwd, runtime)
    except Exception:
        return {"runtime": runtime, "repo_key": "folder:unknown", "display_name": repo_of(cwd) or "?",
                "scope_kind": "folder", "identity_state": "unregistered", "canonical_repo_path": None,
                "worktree_root": cwd or "", "cwd_path": cwd or "", "branch": None}


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


def board_sub_start(key, detail=None):
    """SubagentStart: サブ体数+1・🔵へ（board.py sub-start。行が無ければ何もしない）。
    子03: detail(dict) があれば runtime/model/agent_type/launch_via/prompt を引数へ渡し個体行に enrich する。
    詳細が取れない時は detail=None＝旧来どおり詳細なしで積む（後方互換・非ブロッキング）。"""
    cmd = [BOARD, "sub-start", "--key", key]
    if detail:
        for flag, field in (("--runtime", "runtime"), ("--model", "model"),
                            ("--type", "agent_type"), ("--via", "launch_via"),
                            ("--prompt", "prompt")):
            value = detail.get(field)
            if value:
                cmd += [flag, str(value)]
    subprocess.run(cmd, capture_output=True)


def _subspool():
    if CORE_DIR not in sys.path:
        sys.path.insert(0, CORE_DIR)
    import subspool
    return subspool


def spool_subagent_detail(key, detail):
    """子03: PreToolUse が抜いたサブ詳細を SubagentStart 用に一時スプールへ積む（best-effort）。"""
    try:
        return _subspool().push(key, detail)
    except Exception:
        return 0


def pop_subagent_detail(key):
    """子03: SubagentStart が最古のサブ詳細を1件取り出す（無ければ None・best-effort）。"""
    try:
        return _subspool().pop(key)
    except Exception:
        return None


def board_sub_end(key):
    """SubagentStop: サブ体数-1（0でクランプ）・0になったら🔵→🟢（board.py sub-end）。"""
    subprocess.run([BOARD, "sub-end", "--key", key], capture_output=True)


def board_reconcile():
    """🟢/🔵を実体トランスクリプトで照合し沈黙行を⏸へ＋整列（board.py reconcile）。
    掃除は start-latency に乗らない経路（Stop / SessionStart）からのみ呼ぶ。失敗は無視。"""
    subprocess.run([BOARD, "reconcile"], capture_output=True)


def board_answers(key):
    """子05: 当該セッションに紐づく未消費の質問回答を注入文で受け取る（board.py answers）。
    セッション再開（⏸→🟢）の瞬間だけ呼ぶ＝設計の「次にセッションが動く瞬間に既存hookで渡す」。
    best-effort・失敗/空は空文字。hookをブロックしない。"""
    try:
        out = subprocess.run([BOARD, "answers", "--key", key], capture_output=True, text=True, timeout=5).stdout
        return out.strip()
    except Exception:
        return ""


def board_context_upsert(key, context):
    cmd = [BOARD, "context-upsert", "--key", key]
    pairs = (("runtime", "runtime"), ("repo-key", "repo_key"), ("display-name", "display_name"),
             ("scope-kind", "scope_kind"), ("identity-state", "identity_state"),
             ("repo-path", "canonical_repo_path"), ("worktree-root", "worktree_root"),
             ("cwd-path", "cwd_path"), ("branch", "branch"))
    for flag, field in pairs:
        value = context.get(field)
        if value is not None:
            cmd += ["--" + flag, str(value)]
    try:
        subprocess.run(cmd, capture_output=True, timeout=3)
    except Exception:
        pass


def board_route_prepare(key, turn_id, runtime, context, prompt):
    """Context+pending記録と候補取得を1つのboard.py呼び出しへ直列化する。"""
    event_fingerprint = hashlib.sha256(f"s:{key}|{turn_id}|{runtime}".encode()).hexdigest()
    proposal_id = hashlib.sha256(f"s:{key}|{turn_id}".encode()).hexdigest()[:24]
    cmd = [BOARD, "route-prepare", "--id", proposal_id, "--key", key,
           "--turn", turn_id, "--runtime", runtime, "--repo-key", context["repo_key"],
           "--event-fingerprint", event_fingerprint, "--summary", _safe_summary(prompt)]
    for flag, field in (("display-name", "display_name"), ("scope-kind", "scope_kind"),
                        ("identity-state", "identity_state"), ("repo-path", "canonical_repo_path"),
                        ("worktree-root", "worktree_root"), ("cwd-path", "cwd_path"),
                        ("branch", "branch")):
        value = context.get(field)
        if value is not None:
            cmd += ["--" + flag, str(value)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=4.5).stdout.strip()
        return json.loads(out) if out else {}
    except Exception:
        return {}


def _policy_text():
    try:
        return open(POLICY_FILE, encoding="utf-8").read().strip()
    except Exception:
        return "[FOCUSMAP SESSION ROUTING POLICY v1]\n意味分類はAI、事実記録はPython。曖昧なら確定せず未分類候補にする。"


def _safe_summary(prompt):
    return sanitize_text(prompt, 80)


def _prompt_body(prompt):
    p = (prompt or "").strip() if isinstance(prompt, str) else ""
    marker = "## My request for Codex:"
    if marker in p:
        p = p.split(marker, 1)[1].strip()
    if p.startswith("<in-app-browser-context"):
        p = re.sub(r"^<in-app-browser-context[\s\S]*?</in-app-browser-context>\s*", "", p).strip()
    # runtime保守コマンドは仕事ではない。明示Skill（/skill-name）は除外せず単発候補として記録する。
    if re.match(r"^/(compact|clear|help|hooks)(?:\s|$)", p):
        return ""
    return p


def _turn_id(d, key, prompt):
    explicit = d.get("turn_id") or d.get("turnId")
    if explicit:
        return str(explicit)
    # Claudeはturn_idを渡さない。transcriptのサイズ＋mtimeなら同じhook再試行は同じID、
    # 次のturnはファイル状態の変化で別IDになる。prompt本文はID材料にも保存にも使わない。
    transcript = d.get("transcript_path") or d.get("transcriptPath") or ""
    try:
        stat = os.stat(transcript)
        fingerprint = hashlib.sha256(f"{key}|{stat.st_size}|{stat.st_mtime_ns}".encode()).hexdigest()[:12]
        return f"claude-{stat.st_size:x}-{fingerprint}"
    except Exception:
        return f"claude-{time.time_ns():x}-{uuid.uuid4().hex[:6]}"


def _classification_packet(key, turn_id, context, route_context):
    execution = route_context.get("execution") or context
    session_route = route_context.get("session_route") or {}
    latest = route_context.get("latest_route") or {}
    current_theme = session_route.get("theme_id") or (latest.get("theme_id") if latest.get("status") == "accepted" else None)
    current_plan = session_route.get("plan")
    if current_plan in (None, "", "?", "なし"):
        current_plan = latest.get("plan_slug") if latest.get("status") == "accepted" else None
    repo_line = execution.get("display_name") or context.get("display_name") or "?"
    branch = execution.get("branch") or context.get("branch")
    if branch:
        repo_line += f" / {branch}"
    lines = ["[FOCUSMAP ROUTING CONTEXT]", f"turn: {sanitize_text(turn_id, 80)}",
             f"repo: {sanitize_text(repo_line, 80)}"]
    if current_theme or current_plan:
        lines.append("current: theme=" + sanitize_text(current_theme or "なし", 48)
                     + " / plan=" + sanitize_text(current_plan or "なし", 64))
        lines.append("required: 同じ目的なら現在の所属を維持して分類し、目的が変わった時だけ候補を再評価する。")
    else:
        themes = route_context.get("themes") or []
        plans = route_context.get("plans") or []
        if themes:
            items = [f"{sanitize_text(r.get('id'), 36)}={sanitize_text(r.get('name'), 36)}" for r in themes[:3]]
            lines.append("theme候補: " + " / ".join(items))
        if plans:
            items = [
                f"{sanitize_text(r.get('program_slug'), 48)}="
                f"{sanitize_text(r.get('title') or r.get('program_slug'), 42)}"
                f"[{sanitize_text(r.get('bucket'), 12)}]"
                for r in plans[:3]
            ]
            lines.append("plan候補: " + " / ".join(items))
        if not themes and not plans:
            lines.append("候補: 今日＋このrepoに紐づくTheme/Planなし。無理に確定しない。")
    lines += [
        "required: plan / theme_work / plan_candidate / theme_candidate / unclassified の1つを判断する。",
        f"write-back: {BOARD} route-propose --key {key} --turn {turn_id} --kind <kind> "
        "[--theme <id>] [--plan <slug>] --summary \"<安全な1行>\" --reason \"<短い理由>\"",
        "意味の類似だけならstatus=proposedのまま。ユーザー明示・handoff ID・既存確定routeだけ --status accepted を付ける。",
    ]
    return "\n".join(lines)[:1800]


# ---- hook 本体 ----

def start_register(d, runtime):
    """SessionStart 共通: repo実行Context記録＋生存照合＋キー通知＋固定分類policy。
    session枠は作らず、注入テキストを返す（対象外は None）。
    枠登録は初回プロンプト時（register_prompt の保険 add）へ一本化した（2026-07-08 幽霊枠掃除）。
    プロンプトを持たない/ガードで弾かれる補助セッションは枠が載らなくなる。意味づけは AI が後で update する。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return None
    cwd = d.get("cwd") or ""
    context = _execution_context(cwd, runtime)
    repo = context.get("display_name") or repo_of(cwd)
    board_context_upsert(key, context)
    board_reconcile()
    return (f"[session-board] ボードキー s:{key}（{repo or '?'}・現在 {_now()}）。"
            "行は最初のプロンプト時に登録される。依頼を理解したら "
            "update で目標・種別・今・モデルを正す（手順もその時に注入）。"
            + _plansync_freshness_note(repo)
            + "\n" + _policy_text())


def _plansync_freshness_note(repo):
    """SessionStartの注入文に相乗りする計画ミラー鮮度メモ（注入文のみ・状態遷移は変えない）。
    ~/Private repoでのみ、未同期HEAD差分や secret拒否通知があれば掃除を促す。副作用なし。"""
    if repo != "Private":
        return ""
    note = "\n[plansync] 計画ミラー鮮度: active計画mdを編集したなら plan-ops/scripts/plansync.py sync --all で掃除できる（表示キャッシュ・md正本）。"
    try:
        state_dir = os.environ.get("SESSION_BOARD_STATE_DIR") or os.path.join(os.path.dirname(__file__), "..", "..", "shared", "session-board", "state")
        notices = os.path.join(os.path.normpath(state_dir), "plansync-notices.log")
        if os.path.exists(notices) and os.path.getsize(notices) > 0:
            note += " secret拒否等の通知あり→ state/plansync-notices.log を確認。"
    except Exception:
        pass
    return note


def _now():
    """現在時刻の短表記。AIは自前の時計を持たず開始時点の時刻感覚のまま判断しがちなので、
    毎注入に現在時刻を含めて把握させる（2026-07-09 人間要望・刷新program子02先行分）。"""
    return time.strftime("%m-%d %H:%M")


def _summarize(prompt):
    return _safe_summary(prompt)[:24]


def _first_guide(key, repo, runtime):
    """初回注入（目標が未記入の間）: 記入コマンド・種別/計画列定義・既存目標一覧・二段ルーティング・計画3判定。"""
    goals = board_goals()
    lines = [
        f"[session-board] s:{key} | {repo or '?'} | {runtime} | 現在:{_now()}",
        "最初の依頼を理解したら、ボード行を正す（Bash 1コマンド・このセッションで1回）:",
        f"  {BOARD} update --key {key} --type <{TYPES}> "
        "--goal \"<達成したらこのセッションを閉じられる1行・30字以内>\" "
        "--now \"<いま着手する一歩・20字以内>\" --model <自分のモデル名（小文字短縮 例: fable5）> "
        "--plan \"<企画名[/NN] か なし>\" [--todo <このセッションが進める既存タスクid>]",
        "--todo は当日ボードの既存タスクにこのセッションを紐付ける宣言（任意）。付けると"
        "エージェント行に「テーマ›タスク」が出て、完了時に成果がそのタスク入れ子へ格納される"
        "（未宣言は新見出しへ）。該当タスクが無ければ付けない（宛先を創作しない）。",
        "■ 着手前に必ず1回判断する（この依頼は記録だけか・計画が要るか）:",
        "  ├ サクッと=下の3条件が全YES → 計画不要。そのまま実行し、節目を log で記録するだけ（--plan なし）。",
        "  └ 1つでもNO → 計画が要る。下の計画ルート/3判定で規定の場所に plan を作り、commit して"
        "focusmap へ反映し、update --plan で宣言する（このセッションが「計画外エージェント」からその計画内へ入る）。",
        TYPE_DEFS,
        "計画列: 計画=これから置く先／実装・レビュー=拠り所の計画／リサーチ=任意。"
        "①1〜2ファイル ②容易に戻せる ③目的と完了条件が明確 の全YESなら --plan なし でよい（GLOBAL_AGENTS.md §7のサクッと）。",
    ]
    if goals:
        lines += [
            "いま動いている他の目標: " + "／".join(f"「{g}」" for g in goals[:6]),
            "  → 自分の依頼がどれかと同じ目的なら、その文言をそのまま --goal にコピーして合流"
            "（親名=目標名で成果が1つの親に集まる）。無関係なら新しい目標を立てる。",
        ]
    lines += [
        "計画ルート: repo-registry/repo概要.md で担当repoだけを判定（cwdで決めない）→ "
        "対象repoの最寄りAGENTS.mdで領域・プロジェクト・計画箱を解決→宣言範囲の既存planを検索。既存があれば合流。",
        "repo未登録／AGENTSなし／計画箱未宣言・複数候補／既存plan競合なら、root plansを推定・作成せず停止して人間確認。",
        "計画種別なら、置く前に3判定（詳細: GLOBAL_AGENTS.md §7・areas/AGENTS.md §3）:",
        " ①規模: ①1〜2ファイル ②容易に戻せる ③目的と完了条件が明確 が全YES=サクッと → "
        "計画ファイル不要（--plan なし・ボードとlogで足りる）。1つでもNOなら plan.md 必須。",
        " ②形: 独立に完了する子計画を2本以上生む → program化（program.md＋plans/NN-子.md）。"
        "それ以外は単発 plan.md。",
        " ③完了条件: レビュー項目（「こうなっていれば正しい」形式・対象明示）を書いてから着手。"
        "ライト以上は実装後に評価NN.mdで採点（全PASS=done・areas§3）。雛形: plan-ops new-plan.sh",
        " 置き場: 上の二段ルートで対象repo AGENTS.mdが宣言した計画箱を使う。決めたら update --plan で宣言。",
        "Private起点で対象repoへ書く前は、canonical repo path・plan参照・worktree cwd・許可path・開始時Git snapshotを渡し、"
        "対象repoをrootとする新しい可視sessionへhandoff。既存session IDの移管・reparentはしない。",
        f"節目: {BOARD} log --key {key} --repo <repo> --parent <目標名> --entry <成果1行>"
        "（時刻・所要は自動付与）。サブエージェント起動中: flip --state sub／復帰: flip --state run"
        "（SubagentStart/Stop 受け口の登録環境では sub-start/sub-end が体数ごと自動増減・手動不要）。"
        "完了は人間確認後に finish。開始フローの正本: "
        + os.path.join(os.path.dirname(os.path.dirname(CORE_DIR)), "events", "session-start", "AGENTS.md"),
        plan_create_review_guide_candidate(),
    ]
    return "\n".join(lines)


def _mirror(key, row):
    """2回目以降の注入（毎プロンプト・最小2〜3行）: 行のミラー＋ズレ回収の催促。
    3行目は優先順で出し分け（種別=計画 ＞ 計画:? 催促 ＞ 2行のみ）。両該当は計画3判定のみ。"""
    plan = row.get("plan") or PLACEHOLDER
    lines = [
        f"[session-board] 現在:{_now()} | 目標:{row['goal']} | 今:{row['now']} | 種別:{row['type']} | 計画:{plan}",
        f"→ 実態とズレていたら {BOARD} update --key {key} --now \"<今の一歩>\""
        "（目標・種別・計画が変われば --goal/--type/--plan も）。節目なら log。",
    ]
    if row.get("type") == "計画":
        lines.append("計画3判定: ①サクッと（3条件全YES）→ --plan なし ②子2本以上→program化 "
                     "③レビュー項目を書いてから着手（実装後は評価NN.mdで採点） → 置き場: "
                     "repo概要.md→対象repo AGENTS.md→宣言された計画箱（既存planを先に検索・GLOBAL_AGENTS.md §7・areas§3）。")
    elif row.get("type") == "実装" and plan in (PLACEHOLDER, "なし"):
        lines.append("実装で計画:" + ("?" if plan == PLACEHOLDER else "なし") +
                     " → サクッと3条件（①1〜2ファイル②容易に戻せる③目的と完了条件が明確）を再確認。"
                     "1つでもNOなら plan.md 必須＋実装後に評価NN.mdで採点（agents-registryのreviewer・areas§3）。")
    elif plan == PLACEHOLDER:
        lines.append("計画:? → 拠り所（実装・レビュー）/置き先（計画）を update --plan で。"
                     "①1〜2ファイル②容易に戻せる③目的と完了条件が明確 全YESなら --plan なし。")
    if row.get("type") in ("計画", "実装") and plan not in (PLACEHOLDER, "なし"):
        lines.append("レビュー宣言を確認: 一括の子は束ねてまとめて実施、後続が成果を直接使う子だけ都度。"
                     "同期は planctl・遷移は bucketctl（finish≠archive承認）。")
    return "\n".join(lines)


def register_prompt(d, runtime):
    """UserPromptSubmit 共通: 未登録→枠登録（初回プロンプトで枠を作る主経路・2026-07-08）／⏸→🟢復帰／
    「今」が未記入なら先頭24字を初回だけ仮置き（以降 Python は「今」を上書きしない）。
    repo Context自己修復→turn pending→候補取得を同じhandlerで直列実行し、分類packetを追加する。
    注入テキストを返す（subagent／runtime保守コマンド／空・添付のみ は None）。🔵(sub) は触らない。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return None
    p = _prompt_body(d.get("prompt") or "")
    if not p:
        return None
    cwd = d.get("cwd") or ""
    context = _execution_context(cwd, runtime)
    repo = context.get("display_name") or repo_of(cwd)
    turn_id = _turn_id(d, key, p)
    # 順序保証が必要な分類処理は、このhandlerから後段のroute-prepareを1回だけ呼ぶ。
    row = board_show(key)
    first_prompt = row is None
    if first_prompt:
        board_add(key, repo, f"{runtime}/{PLACEHOLDER}")
        row = board_show(key) or {"state": "run", "goal": PLACEHOLDER, "now": PLACEHOLDER,
                                  "type": "その他", "repo": repo or "?",
                                  "who": f"{runtime}/{PLACEHOLDER}", "plan": PLACEHOLDER}
    resuming = row["state"] == "wait"   # ⏸→🟢＝「次にセッションが動く瞬間」。ここでだけ回答を注入する。
    if resuming:
        board_flip(key, "run")
    if row["now"] == PLACEHOLDER:      # 初回だけの仮置き（枠を空にしない）。意味づけはAIの update --now
        board_update(key, now=_summarize(p))
        row["now"] = _summarize(p)
    # 長い開始ガイドは「目標が?の間」ではなく最初の意味あるPromptだけ。AIがupdateし損ねても再注入しない。
    base = _first_guide(key, row.get("repo") or repo, runtime) if first_prompt else _mirror(key, row)
    routing_packet = _classification_packet(key, turn_id, context, board_route_prepare(key, turn_id, runtime, context, p))
    base = f"{base}\n{routing_packet}"
    if resuming:      # 再開時だけ inbox を引く（毎プロンプトの読取を避ける・子05段階4）
        answers = board_answers(key)
        if answers:
            return f"{base}\n{answers}"
    return base


def stop_flip(d):
    """Stop 共通: run のときだけ⏸(wait)へ。sub／wait／missing は触らない。ブロックしない。
    併せてボード全体を生存照合＋整列（Stop=ターン終了なので開始レイテンシに無関係）。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return
    if board_check(key) == "run":
        board_flip(key, "wait")
    board_reconcile()
