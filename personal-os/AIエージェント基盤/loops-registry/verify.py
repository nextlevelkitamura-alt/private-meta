#!/usr/bin/env python3
"""実行loop一覧の正本MDを検査し、白基調の人間向けHTMLを生成する。"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import plistlib
import re
import subprocess
import sys
from collections import OrderedDict
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo


HERE = Path(__file__).resolve().parent
REGISTRY = HERE
LOOPS_DIR = HERE / "loops"
MD_PATH = HERE / "実行loop一覧.md"
HTML_PATH = HERE / "実行loop一覧.html"

OLD_FILES = (
    HERE / "実行一覧",
    HERE / "personal-os.md",
    HERE / "personal-os.html",
    HERE / "nextlevel-career.md",
)
FORBIDDEN_DIRS = {"daily-digest", "renderer", "exec-audit", "inbox-patrol", "watch-keeper"}
REQUIRED_FIELDS = (
    "領域",
    "分類",
    "scope",
    "目的",
    "内部処理",
    "実行方法",
    "発火",
    "発火設定",
    "launchd構成",
    "統合判断",
    "失敗時",
    "記録",
    "runner",
    "launchd label",
    "正本",
    "plist",
    "意図状態",
    "最終実機確認",
)
MARKER_RE = re.compile(r"<!-- LOOP:([a-z0-9][a-z0-9-]*) -->")
FIELD_RE = re.compile(r"^- ([^:\n]+):[ \t]*(.+)$", re.MULTILINE)
HASH_RE = re.compile(r'<meta name="source-sha256" content="([0-9a-f]{64})">')


def source_hash(path: Path = MD_PATH) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_path(raw: str) -> Path:
    expanded = Path(raw).expanduser()
    return expanded.resolve() if expanded.is_absolute() else (HERE / expanded).resolve()


def parse_overview(path: Path = MD_PATH) -> list[dict[str, str]]:
    text = path.read_text(encoding="utf-8")
    matches = list(MARKER_RE.finditer(text))
    if not matches:
        raise ValueError("実行loop一覧.mdにLOOPマーカーがありません")

    loops: list[dict[str, str]] = []
    seen: set[str] = set()
    for index, match in enumerate(matches):
        name = match.group(1)
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end() : end]
        if name in seen:
            raise ValueError(f"LOOPマーカーが重複しています: {name}")
        if not re.search(rf"^### `?{re.escape(name)}`?$", body, re.MULTILINE):
            raise ValueError(f"LOOPマーカー直後の見出しが一致しません: {name}")

        fields = {key.strip(): value.strip() for key, value in FIELD_RE.findall(body)}
        missing = [key for key in REQUIRED_FIELDS if not fields.get(key)]
        if missing:
            raise ValueError(f"{name}の必須項目が不足: {', '.join(missing)}")
        loops.append({"name": name, **fields})
        seen.add(name)
    return loops


def normalize_schedule(data: dict[str, object]) -> dict[str, object]:
    keys = [key for key in ("StartInterval", "StartCalendarInterval") if key in data]
    if len(keys) != 1:
        raise ValueError("StartIntervalまたはStartCalendarIntervalをちょうど1つ指定してください")
    key = keys[0]
    value = data[key]
    if key == "StartInterval":
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            raise ValueError("StartIntervalは正の整数秒で指定してください")
        return {key: value}

    entries = value if isinstance(value, list) else [value]
    if not entries or not all(isinstance(entry, dict) for entry in entries):
        raise ValueError("StartCalendarIntervalは辞書または辞書の配列で指定してください")
    normalized_entries: list[dict[str, int]] = []
    for entry in entries:
        normalized: dict[str, int] = {}
        for field, raw in entry.items():
            if isinstance(raw, bool) or not isinstance(raw, int):
                raise ValueError(f"StartCalendarInterval.{field}は整数で指定してください")
            normalized[str(field)] = raw
        normalized_entries.append(dict(sorted(normalized.items())))
    normalized_entries.sort(key=lambda row: json.dumps(row, ensure_ascii=False, sort_keys=True))
    return {key: normalized_entries}


def parse_md_schedule(item: dict[str, str]) -> dict[str, object]:
    try:
        raw = json.loads(item["発火設定"])
    except json.JSONDecodeError as exc:
        raise ValueError(f"発火設定がJSONではありません: {exc.msg}") from exc
    if not isinstance(raw, dict):
        raise ValueError("発火設定はJSON objectで指定してください")
    return normalize_schedule(raw)


def parse_internal_steps(item: dict[str, str]) -> list[dict[str, str]]:
    try:
        raw = json.loads(item["内部処理"])
    except json.JSONDecodeError as exc:
        raise ValueError(f"内部処理がJSONではありません: {exc.msg}") from exc
    if not isinstance(raw, list) or not raw:
        raise ValueError("内部処理は1件以上のJSON arrayで指定してください")
    steps: list[dict[str, str]] = []
    for index, entry in enumerate(raw, start=1):
        if not isinstance(entry, dict):
            raise ValueError(f"内部処理[{index}]はobjectで指定してください")
        name = entry.get("name")
        detail = entry.get("detail")
        if not isinstance(name, str) or not name.strip() or not isinstance(detail, str) or not detail.strip():
            raise ValueError(f"内部処理[{index}]にnameとdetailが必要です")
        steps.append({"name": name.strip(), "detail": detail.strip()})
    return steps


def launchd_snapshot(item: dict[str, str]) -> dict[str, str]:
    target = f"gui/{os.getuid()}/{item['launchd label']}"
    result = subprocess.run(["launchctl", "print", target], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return {"health": "stopped", "label": "未ロード", "state": "unloaded", "runs": "0", "exit": "-"}

    output = result.stdout
    def first(pattern: str, default: str) -> str:
        match = re.search(pattern, output, re.MULTILINE)
        return match.group(1).strip() if match else default

    state = first(r"^\s*state\s*=\s*(.+)$", "unknown")
    runs = first(r"^\s*runs\s*=\s*(.+)$", "0")
    exit_code = first(r"^\s*last exit code\s*=\s*(.+)$", "unknown")
    if exit_code in {"0", "(never exited)"}:
        health = "healthy"
        label = "登録済み" if exit_code == "(never exited)" else "正常"
    else:
        health = "warning"
        label = "要確認"
    return {"health": health, "label": label, "state": state, "runs": runs, "exit": exit_code}


def validate_state(item: dict[str, str], today: date | None = None) -> list[str]:
    state = item["意図状態"]
    if state == "稼働中":
        return []
    if state != "一時停止":
        return [f"意図状態は稼働中または一時停止にしてください: {state}"]

    missing = [field for field in ("停止理由", "停止日", "再判断期限") if not item.get(field)]
    if missing:
        return [f"一時停止の必須項目が不足: {', '.join(missing)}"]
    try:
        stopped = date.fromisoformat(item["停止日"])
        deadline = date.fromisoformat(item["再判断期限"])
    except ValueError:
        return ["停止日と再判断期限はYYYY-MM-DDで指定してください"]

    errors: list[str] = []
    if deadline < stopped:
        errors.append("再判断期限が停止日より前です")
    if (deadline - stopped).days > 30:
        errors.append("一時停止の再判断期限が30日を超えています")
    current = today or datetime.now(ZoneInfo("Asia/Tokyo")).date()
    if deadline < current:
        errors.append(f"一時停止の再判断期限が切れています: {deadline.isoformat()}")
    return errors


def load_plist(path: Path) -> dict[str, object]:
    converted = subprocess.run(
        ["plutil", "-convert", "binary1", "-o", "-", str(path)],
        capture_output=True,
        check=False,
    )
    if converted.returncode != 0:
        message = converted.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(message or "plutil変換に失敗")
    parsed = plistlib.loads(converted.stdout)
    if not isinstance(parsed, dict):
        raise ValueError("plist rootがdictionaryではありません")
    return parsed


def group_loops(loops: list[dict[str, str]]) -> OrderedDict[str, list[dict[str, str]]]:
    groups: OrderedDict[str, list[dict[str, str]]] = OrderedDict()
    for item in loops:
        groups.setdefault(item["領域"], []).append(item)
    return groups


def destination_kind(record: str) -> tuple[str, str]:
    if "スプシ" in record or "Google" in record:
        return "sheet", "Google Sheets"
    if "Notion" in record:
        return "notion", "Notion + ローカル"
    return "local", "ローカルログ"


def next_label(item: dict[str, str]) -> str:
    schedule = parse_md_schedule(item)
    if "StartInterval" in schedule:
        seconds = int(schedule["StartInterval"])
        if seconds < 60:
            return f"次の{seconds}秒周期"
        return f"次の{seconds // 60}分周期"
    return "次回スケジュール"


def render_loop_rows(loops: list[dict[str, str]], snapshots: dict[str, dict[str, str]]) -> str:
    parts: list[str] = []
    for category, items in OrderedDict(
        (category, [item for item in loops if item["分類"] == category])
        for category in dict.fromkeys(item["分類"] for item in loops)
    ).items():
        parts.append(f'<div class="category-label">{html.escape(category)} <span>{len(items)} loop</span></div>')
        for item in items:
            name = html.escape(item["name"])
            snapshot = snapshots[item["name"]]
            state_class = snapshot["health"]
            state_label = snapshot["label"]
            destination_class, destination_label = destination_kind(item["記録"])
            process_steps = "".join(
                f'<li><span>{index}</span><div><strong>{html.escape(step["name"])}</strong>'
                f'<p>{html.escape(step["detail"])}</p></div></li>'
                for index, step in enumerate(parse_internal_steps(item), start=1)
            )
            parts.append(
                f'''<details class="loop-row" data-loop-name="{name}">
                  <summary>
                    <span class="chevron" aria-hidden="true"></span>
                    <span class="status-dot {state_class}" title="launchd: {state_label}"></span>
                    <span class="loop-copy"><code>{name}</code><small>{html.escape(item["目的"])}</small></span>
                    <span class="timing"><small>実行間隔</small><strong>{html.escape(item["発火"])}</strong></span>
                    <span class="next"><small>次回</small><strong>{html.escape(next_label(item))}</strong></span>
                    <span class="destination {destination_class}">{destination_label}</span>
                  </summary>
                  <section class="process-block"><h3>内部処理</h3><p class="process-lead">起動後は、次の順番・条件で処理する。</p><ol class="process-steps">{process_steps}</ol></section>
                  <dl class="detail-strip">
                    <div class="detail-item"><dt>実行方法</dt><dd>{html.escape(item["実行方法"])}</dd></div>
                    <div class="detail-item"><dt>失敗時</dt><dd>{html.escape(item["失敗時"])}</dd></div>
                    <div class="detail-item"><dt>記録先</dt><dd>{html.escape(item["記録"])}</dd></div>
                    <div class="detail-item"><dt>正本</dt><dd><code>{html.escape(item["正本"])}</code></dd></div>
                    <div class="detail-item"><dt>launchd構成</dt><dd>{html.escape(item["launchd構成"])}</dd></div>
                    <div class="detail-item"><dt>統合判断</dt><dd>{html.escape(item["統合判断"])}</dd></div>
                  </dl>
                  <div class="row-meta"><code>{html.escape(item["launchd label"])}</code><span>launchd: {html.escape(state_label)} ／ state={html.escape(snapshot["state"])} ／ runs={html.escape(snapshot["runs"])} ／ last exit={html.escape(snapshot["exit"])}</span></div>
                </details>'''
            )
    return "".join(parts)


def render_html(loops: list[dict[str, str]], digest: str) -> str:
    groups = group_loops(loops)
    snapshots = {item["name"]: launchd_snapshot(item) for item in loops}
    healthy_count = sum(snapshot["health"] == "healthy" for snapshot in snapshots.values())
    warning_count = sum(snapshot["health"] == "warning" for snapshot in snapshots.values())
    stopped_count = sum(snapshot["health"] == "stopped" for snapshot in snapshots.values())
    snapshot_at = datetime.now(ZoneInfo("Asia/Tokyo")).strftime("%Y/%m/%d %H:%M:%S")
    shortest = min(
        int(parse_md_schedule(item)["StartInterval"])
        for item in loops
        if "StartInterval" in parse_md_schedule(item)
    )
    domain_meta = {
        "Personal OS": ("personal", "Mac / AIエージェント基盤の運用", "基盤"),
        "仕事": ("work", "仕事repoが所有する業務自動化", "仕事"),
    }
    panels: list[str] = []
    for domain, items in groups.items():
        panel_class, description, icon_label = domain_meta[domain]
        active = sum(snapshots[item["name"]]["health"] == "healthy" for item in items)
        attention = sum(snapshots[item["name"]]["health"] == "warning" for item in items)
        stopped = sum(snapshots[item["name"]]["health"] == "stopped" for item in items)
        panels.append(
            f'''<section class="domain {panel_class}" aria-labelledby="domain-{panel_class}">
              <header class="domain-header">
                <div class="domain-title"><span class="domain-icon">{icon_label}</span><div><h2 id="domain-{panel_class}">{html.escape(domain)}</h2><p>{description}</p></div></div>
                <div class="domain-health"><strong>{len(items)} loop</strong><span class="health-pill"><i></i>{active} 正常</span><span class="health-pill warning"><i></i>{attention} 要確認</span><span class="health-pill stopped"><i></i>{stopped} 停止</span></div>
              </header>
              <div class="column-head" aria-hidden="true"><span>状態</span><span>loop名 / 何をする</span><span>実行間隔</span><span>次回</span><span>記録先</span></div>
              <div class="loop-list">{render_loop_rows(items, snapshots)}</div>
            </section>'''
        )
    return f'''<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="source-sha256" content="{digest}">
  <title>実行loop一覧</title>
  <style>
    :root {{
      color-scheme: light;
      --background:#f7f9fc; --surface:#ffffff; --surface-subtle:#f8fafc;
      --text:#182033; --muted:#667085; --line:#d9e0ea; --line-soft:#e9edf3;
      --primary:#1769e0; --primary-soft:#edf5ff; --personal:#2878e7;
      --success:#17a34a; --success-soft:#ecf9f0; --work:#169447; --work-soft:#effbf3;
      --warning:#f2a100; --warning-soft:#fff8e8; --danger:#dc2f3f;
      --shadow:0 8px 28px rgba(34,52,82,.055);
      --sans:-apple-system,BlinkMacSystemFont,"Hiragino Sans","Yu Gothic",sans-serif;
      --mono:"SF Mono",Menlo,Consolas,monospace;
    }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:var(--background); color:var(--text); font:14px/1.55 var(--sans); -webkit-font-smoothing:antialiased; }}
    main {{ width:min(1460px,calc(100% - 48px)); margin:0 auto; padding:28px 0 64px; }}
    .page-header {{ display:flex; justify-content:space-between; gap:28px; align-items:flex-start; margin:0 6px 18px; }}
    h1 {{ margin:0; font-size:32px; line-height:1.2; letter-spacing:-.035em; }}
    .lead {{ margin:5px 0 0; color:var(--muted); font-size:14px; }}
    .legend {{ display:flex; gap:18px; padding:8px 13px; border:1px solid var(--line); border-radius:8px; background:var(--surface); color:#344054; font-size:12px; }}
    .legend span,.health-pill {{ display:inline-flex; align-items:center; gap:7px; white-space:nowrap; }}
    .legend i,.health-pill i {{ width:10px; height:10px; border-radius:50%; background:var(--success); }}
    .legend .warn {{ background:var(--warning); }} .legend .stop {{ background:var(--danger); }}
    .summary {{ display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:15px; }}
    .metric {{ min-height:100px; display:flex; align-items:center; gap:16px; padding:17px 20px; border:1px solid var(--line); border-radius:10px; background:var(--surface); box-shadow:var(--shadow); }}
    .metric-icon {{ display:grid; place-items:center; flex:0 0 44px; height:44px; border:3px solid currentColor; border-radius:50%; color:var(--primary); font-size:20px; font-weight:700; }}
    .metric.success .metric-icon,.metric.success strong {{ color:var(--success); }}
    .metric small {{ display:block; color:var(--muted); font-size:12px; }}
    .metric strong {{ display:block; margin-top:2px; color:var(--primary); font-size:21px; line-height:1.25; }}
    .metric p {{ margin:3px 0 0; color:var(--muted); font-size:11px; }}
    .domain {{ overflow:hidden; margin-top:12px; border:1px solid #abd0ff; border-radius:12px; background:var(--surface); box-shadow:var(--shadow); }}
    .domain.work {{ border-color:#a9dfbb; }}
    .domain-header {{ display:flex; justify-content:space-between; gap:20px; align-items:center; padding:13px 20px; background:#f7fbff; border-bottom:1px solid #cfe2fb; }}
    .work .domain-header {{ background:#f6fcf8; border-color:#d0ead9; }}
    .domain-title,.domain-health {{ display:flex; align-items:center; gap:13px; }}
    .domain-icon {{ display:grid; place-items:center; min-width:44px; height:38px; padding:0 8px; border-radius:7px; background:var(--personal); color:#fff; font-size:11px; font-weight:800; }}
    .work .domain-icon {{ background:var(--work); }}
    h2 {{ display:inline; margin:0; font-size:23px; line-height:1.2; letter-spacing:-.02em; }}
    .domain-title p {{ display:inline; margin-left:12px; color:var(--muted); font-size:12px; }}
    .domain-health>strong {{ margin-right:10px; color:var(--personal); font-size:15px; }}
    .work .domain-health>strong {{ color:var(--work); }}
    .health-pill {{ padding:5px 10px; border:1px solid var(--line); border-radius:7px; background:#fff; font-size:11px; font-weight:600; }}
    .health-pill.warning i {{ background:var(--warning); }} .health-pill.stopped i {{ background:var(--danger); }}
    .column-head,.loop-row summary {{ display:grid; grid-template-columns:44px minmax(310px,1fr) 165px 170px 190px; align-items:center; }}
    .column-head {{ min-height:30px; padding:0 18px; color:var(--muted); font-size:11px; }}
    .column-head span:first-child {{ grid-column:1; }} .column-head span:nth-child(2) {{ grid-column:2; }}
    .category-label {{ padding:7px 20px 5px; border-top:1px solid var(--line-soft); background:#fbfcfe; color:#526274; font-size:11px; font-weight:700; letter-spacing:.03em; }}
    .category-label span {{ margin-left:5px; color:#98a2b3; font-weight:500; }}
    .loop-row {{ margin:0 12px 5px; border:1px solid var(--line); border-radius:8px; background:#fff; transition:border-color .15s,box-shadow .15s; }}
    .loop-row:hover {{ border-color:#b9c8da; box-shadow:0 3px 10px rgba(36,52,76,.05); }}
    .loop-row summary {{ min-height:58px; padding:7px 10px; list-style:none; cursor:pointer; }}
    .loop-row summary::-webkit-details-marker {{ display:none; }}
    .chevron {{ width:8px; height:8px; border-right:2px solid #667085; border-bottom:2px solid #667085; transform:rotate(-45deg); transition:transform .15s; }}
    details[open] .chevron {{ transform:rotate(45deg); }}
    .status-dot {{ position:absolute; margin-left:23px; width:14px; height:14px; border-radius:50%; background:var(--success); }}
    .status-dot.warning {{ background:var(--warning); }} .status-dot.stopped {{ background:var(--danger); }}
    .loop-copy {{ min-width:0; padding-right:18px; }}
    .loop-copy code {{ display:block; color:var(--text); font:700 14px/1.35 var(--mono); overflow-wrap:anywhere; }}
    .loop-copy small {{ display:block; margin-top:2px; color:#475467; font-size:11px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }}
    .timing small,.next small {{ display:block; color:var(--muted); font-size:10px; }}
    .timing strong,.next strong {{ display:block; color:#344054; font-size:12px; }} .next strong {{ color:var(--primary); }}
    .destination {{ justify-self:start; padding:5px 10px; border:1px solid var(--line); border-radius:7px; background:#fff; color:#344054; font-size:11px; font-weight:600; }}
    .destination.sheet {{ color:#087a35; border-color:#cfe8d8; background:#f7fcf8; }} .destination.notion {{ color:#353945; }}
    .process-block {{ margin:0 10px 10px; padding:14px 15px; border:1px solid #d9e8fb; border-radius:8px; background:#f8fbff; }}
    .process-block h3 {{ margin:0; font-size:13px; }} .process-lead {{ margin:2px 0 11px; color:var(--muted); font-size:10px; }}
    .process-steps {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px 12px; margin:0; padding:0; list-style:none; }}
    .process-steps li {{ display:flex; gap:9px; min-width:0; padding:8px 9px; border:1px solid var(--line-soft); border-radius:7px; background:#fff; }}
    .process-steps li>span {{ display:grid; place-items:center; flex:0 0 22px; height:22px; border-radius:50%; background:var(--primary-soft); color:var(--primary); font-size:10px; font-weight:800; }}
    .process-steps strong {{ display:block; color:#344054; font-size:11px; }} .process-steps p {{ margin:2px 0 0; color:#667085; font-size:10px; }}
    .detail-strip {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:1px; margin:0 10px; overflow:hidden; border:1px solid var(--line-soft); border-radius:7px; background:var(--line-soft); }}
    .detail-item {{ min-width:0; padding:9px 11px; background:var(--surface-subtle); }} .detail-item.wide {{ grid-column:1/-1; }}
    .detail-item dt {{ color:var(--muted); font-size:10px; font-weight:700; }} .detail-item dd {{ margin:2px 0 0; color:#475467; font-size:11px; overflow-wrap:anywhere; }}
    code {{ font-family:var(--mono); }}
    .row-meta {{ display:flex; justify-content:space-between; gap:16px; padding:7px 12px 9px; color:#8792a2; font-size:9px; }}
    .rule {{ margin-top:14px; padding:13px 16px; border:1px solid #cfe2fb; border-radius:9px; background:var(--primary-soft); color:#3d4e64; font-size:12px; }}
    .rule strong {{ color:var(--primary); }}
    .snapshot-note {{ margin:-2px 0 14px; color:var(--muted); font-size:10px; text-align:right; }}
    .live-plan {{ margin-top:14px; padding:17px 18px; border:1px solid var(--line); border-radius:10px; background:#fff; }}
    .live-plan h2 {{ margin:0; font-size:16px; }} .live-plan>p {{ margin:3px 0 12px; color:var(--muted); font-size:11px; }}
    .live-grid {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; }} .live-card {{ padding:12px; border:1px solid var(--line-soft); border-radius:8px; background:var(--surface-subtle); }}
    .live-card strong {{ display:block; font-size:12px; }} .live-card p {{ margin:4px 0 0; color:#667085; font-size:10px; }} .live-card.recommended {{ border-color:#b8d9c3; background:var(--work-soft); }}
    footer {{ margin-top:12px; color:var(--muted); font-size:9px; overflow-wrap:anywhere; }}
    @media (max-width:1050px) {{
      main {{ width:min(100% - 24px,980px); }} .summary {{ grid-template-columns:repeat(2,1fr); }}
      .column-head {{ display:none; }} .loop-row summary {{ grid-template-columns:44px minmax(260px,1fr) 130px 150px; }}
      .destination {{ display:none; }} .domain-header {{ align-items:flex-start; }} .domain-health {{ flex-wrap:wrap; justify-content:flex-end; }}
    }}
    @media (max-width:720px) {{
      main {{ padding-top:20px; }} .page-header,.domain-header {{ align-items:flex-start; flex-direction:column; }} .legend {{ flex-wrap:wrap; gap:9px 14px; }}
      .summary {{ grid-template-columns:1fr; }} .metric {{ min-height:82px; }} .domain-health {{ justify-content:flex-start; }}
      .domain-title p {{ display:block; margin:3px 0 0; }} .loop-row summary {{ grid-template-columns:36px 1fr; gap:3px; }}
      .status-dot {{ margin-left:18px; }} .timing,.next {{ grid-column:2; display:flex; gap:8px; align-items:baseline; }} .detail-strip,.process-steps,.live-grid {{ grid-template-columns:1fr; }}
    }}
  </style>
</head>
<body>
  <main>
    <header class="page-header"><div><h1>実行loop一覧</h1><p class="lead">Macで動く自作loopを2領域で管理</p></div><div class="legend" aria-label="状態の凡例"><span><i></i>正常</span><span><i class="warn"></i>要確認</span><span><i class="stop"></i>停止</span></div></header>
    <section class="summary" aria-label="一覧の概要">
      <div class="metric success"><span class="metric-icon">✓</span><div><small>launchd健康状態</small><strong>{'正常' if warning_count == 0 and stopped_count == 0 else '要確認'}</strong><p>正常{healthy_count}・要確認{warning_count}・停止{stopped_count}</p></div></div>
      <div class="metric"><span class="metric-icon">▶</span><div><small>登録済みloop数</small><strong>{len(loops)-stopped_count} / {len(loops)}</strong><p>launchctlの実機スナップショット</p></div></div>
      <div class="metric"><span class="metric-icon">↻</span><div><small>最短実行間隔</small><strong>{shortest}秒ごと</strong><p>正確な次回時刻はlaunchdが管理</p></div></div>
      <div class="metric"><span class="metric-icon">◷</span><div><small>状態取得時刻</small><strong>{snapshot_at}</strong><p>実機の状態はlaunchctlが正本</p></div></div>
    </section>
    <p class="snapshot-note">状態はHTML生成時のスナップショット。更新: <code>python3 verify.py --write-html</code></p>
    {''.join(panels)}
    <section class="live-plan"><h2>launchdをいつでもUIで見る設計</h2><p>静的な説明と変動する実機状態を混ぜず、余計な短周期loopも増やさない。</p><div class="live-grid">
      <div class="live-card"><strong>現在: 一覧HTML</strong><p>処理内容・周期・失敗時・記録先の正本ビュー。状態は再生成時のlaunchctlスナップショット。</p></div>
      <div class="live-card recommended"><strong>推奨: 開いている間だけlive</strong><p>localhostの小さなviewerがページ閲覧中だけ10〜30秒ごとにlaunchctlを読む。新しい1分launchdは不要。</p></div>
      <div class="live-card"><strong>避ける: 状態取得loopの乱立</strong><p>labelごとの監視loopや同周期の親loopを増やすと、確認対象そのものが増えて逆効果になる。</p></div>
    </div></section>
    <section class="rule"><strong>統合判断</strong>　1分周期はNextLevel dispatcher 1本へ6処理を統合済み。現在の重複候補は、同じ実装・同じ4分周期で動く関東／全国worker-searchの2本。停止・再登録を伴うため統合実装は別の人間ゲートで行う。</section>
    <section class="rule"><strong>新しいloopを追加するとき</strong>　正本MDへ「領域: Personal OS / 仕事」と内容分類を追記し、<code>python3 verify.py --write-html &amp;&amp; python3 verify.py</code>で表示と実体を揃える。ログ本文は集約せず、ここにはローカル・Notion・Google Sheetsなどの記録先だけを書く。</section>
    <footer>正本: 実行loop一覧.md ／ source-sha256: {digest}</footer>
  </main>
</body>
</html>
'''


def write_html(loops: list[dict[str, str]]) -> None:
    digest = source_hash()
    HTML_PATH.write_text(render_html(loops, digest), encoding="utf-8")
    print(f"WROTE {HTML_PATH.name} source-sha256={digest}")


def verify(loops: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    global_listed = {item["name"] for item in loops if item["scope"] == "global"}
    actual_global = {path.name for path in LOOPS_DIR.iterdir() if path.is_dir() and not path.name.startswith(".")}
    if global_listed != actual_global:
        errors.append(
            "global一覧とloop実体が不一致: "
            f"MDのみ={sorted(global_listed - actual_global)} 実体のみ={sorted(actual_global - global_listed)}"
        )

    if any(path.exists() or path.is_symlink() for path in OLD_FILES):
        remaining = [path.name for path in OLD_FILES if path.exists() or path.is_symlink()]
        errors.append(f"旧一覧ファイルが残っています: {remaining}")
    present_forbidden = sorted(name for name in FORBIDDEN_DIRS if (LOOPS_DIR / name).exists())
    if present_forbidden:
        errors.append(f"廃止loopが残っています: {present_forbidden}")

    for item in loops:
        name = item["name"]
        if item["領域"] not in {"Personal OS", "仕事"}:
            errors.append(f"{name}: 領域はPersonal OSまたは仕事にしてください: {item['領域']}")
        if item["scope"] == "global" and item["領域"] != "Personal OS":
            errors.append(f"{name}: global loopの領域はPersonal OSにしてください")
        if item["scope"] == "repo-local" and item["領域"] != "仕事":
            errors.append(f"{name}: 現行repo-local loopの領域は仕事にしてください")
        if item["scope"] not in {"global", "repo-local"}:
            errors.append(f"{name}: scopeはglobalまたはrepo-localにしてください: {item['scope']}")
        if item["runner"] not in {"script", "ai"}:
            errors.append(f"{name}: runnerはscriptまたはaiにしてください: {item['runner']}")
        if not item["統合判断"].startswith(("維持。", "統合済み。", "統合候補。")):
            errors.append(f"{name}: 統合判断は維持。／統合済み。／統合候補。のいずれかで始めてください")
        try:
            parse_internal_steps(item)
        except ValueError as exc:
            errors.append(f"{name}: {exc}")
        errors.extend(f"{name}: {error}" for error in validate_state(item))

        source = resolve_path(item["正本"])
        if not source.is_file():
            errors.append(f"{name}: 正本が存在しません: {item['正本']}")
        if item["scope"] == "global":
            expected = (LOOPS_DIR / name / "loop.md").resolve()
            if source != expected:
                errors.append(f"{name}: global正本がloop.md実体と一致しません: {item['正本']}")

        plist_path = resolve_path(item["plist"])
        if not plist_path.is_file():
            errors.append(f"{name}: plistが存在しません: {item['plist']}")
            continue
        lint = subprocess.run(["plutil", "-lint", str(plist_path)], capture_output=True, text=True, check=False)
        if lint.returncode != 0:
            errors.append(f"{name}: plutil失敗: {(lint.stderr or lint.stdout).strip()}")
            continue
        try:
            plist_data = load_plist(plist_path)
            md_schedule = parse_md_schedule(item)
            plist_schedule = normalize_schedule(plist_data)
        except (ValueError, plistlib.InvalidFileException) as exc:
            errors.append(f"{name}: plist/発火設定の読取失敗: {exc}")
            continue
        if plist_data.get("Label") != item["launchd label"]:
            errors.append(
                f"{name}: launchd labelがplistと不一致: "
                f"MD={item['launchd label']} plist={plist_data.get('Label')}"
            )
        if md_schedule != plist_schedule:
            errors.append(
                f"{name}: MDとplistの発火設定が不一致: "
                f"MD={json.dumps(md_schedule, ensure_ascii=False, sort_keys=True)} "
                f"plist={json.dumps(plist_schedule, ensure_ascii=False, sort_keys=True)}"
            )

    if not HTML_PATH.is_file():
        errors.append("実行loop一覧.htmlがありません。--write-htmlを実行してください")
        return errors
    html_text = HTML_PATH.read_text(encoding="utf-8")
    hash_match = HASH_RE.search(html_text)
    expected_hash = source_hash()
    if not hash_match:
        errors.append("HTMLにsource-sha256 metaがありません")
    elif hash_match.group(1) != expected_hash:
        errors.append(f"MDとHTMLのsource-sha256が不一致: MD={expected_hash} HTML={hash_match.group(1)}")

    listed = {item["name"] for item in loops}
    html_names = set(re.findall(r'data-loop-name="([a-z0-9-]+)"', html_text))
    if html_names != listed:
        errors.append(
            "MD掲載名とHTML掲載名が不一致: "
            f"MDのみ={sorted(listed - html_names)} HTMLのみ={sorted(html_names - listed)}"
        )
    for item in loops:
        if html.escape(item["launchd label"]) not in html_text:
            errors.append(f"{item['name']}: launchd labelがHTMLにありません")
    return errors


def run_self_tests() -> int:
    failures: list[str] = []
    actual = normalize_schedule({"StartInterval": 300})
    wrong = normalize_schedule({"StartInterval": 999})
    if actual == wrong:
        failures.append("発火誤記999秒を検出できない")
    else:
        print("PASS fixture: 誤発火設定999秒は不一致")

    base = {
        "name": "fixture",
        "意図状態": "一時停止",
        "停止理由": "保守待ち",
        "停止日": "2026-07-01",
        "再判断期限": "2026-07-30",
    }
    fixed_today = date(2026, 7, 11)
    if validate_state(base, fixed_today):
        failures.append("期限内一時停止を受理できない")
    else:
        print("PASS fixture: 期限内一時停止")
    missing_reason = {key: value for key, value in base.items() if key != "停止理由"}
    if not validate_state(missing_reason, fixed_today):
        failures.append("停止理由欠落を検出できない")
    else:
        print("PASS fixture: 停止理由欠落はFAIL")
    over_30 = {**base, "停止日": "2026-07-01", "再判断期限": "2026-08-01"}
    if not any("30日" in error for error in validate_state(over_30, fixed_today)):
        failures.append("30日超の一時停止を検出できない")
    else:
        print("PASS fixture: 30日超はFAIL")
    expired = {**base, "停止日": "2026-06-01", "再判断期限": "2026-06-20"}
    if not any("期限が切れ" in error for error in validate_state(expired, fixed_today)):
        failures.append("期限切れ一時停止を検出できない")
    else:
        print("PASS fixture: 期限切れはFAIL")

    if failures:
        for failure in failures:
            print(f"FAIL fixture: {failure}", file=sys.stderr)
        return 1
    print("PASS: adversarial schedule / paused-state fixtures")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-html", action="store_true", help="正本MDから同階層HTMLを再生成する")
    parser.add_argument("--self-test", action="store_true", help="発火誤記と一時停止期限のfixtureを検査する")
    args = parser.parse_args()
    if args.self_test:
        return run_self_tests()
    try:
        loops = parse_overview()
    except (OSError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    if args.write_html:
        write_html(loops)
    errors = verify(loops)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {len(loops)} loops / {len(group_loops(loops))} categories / plist / MD / HTML are consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
