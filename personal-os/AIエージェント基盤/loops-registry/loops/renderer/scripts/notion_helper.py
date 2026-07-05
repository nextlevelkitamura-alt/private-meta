#!/usr/bin/env python3
# renderer / notion_helper.py — notion-push.sh(N1)・notion-board.sh(N3)・notion-inbox-pull.sh(N2)
# から呼ばれるJSON変換ヘルパ（サブコマンド方式）。HTTP通信は行わない（curlは各呼び出し元スクリプトが
# 担う）。secretは一切扱わない（NOTION_TOKENはこのスクリプトの引数にも標準入力にも渡らない）。
#
# サブコマンド（N1向け）:
#   find-title-id --title T   : stdin=Notion検索API or 子ブロック一覧APIのレスポンスJSON。
#                                 タイトルがTと完全一致する page / child_page のidを1行出す（無ければexit 1）。
#   list-ids                  : stdin=子ブロック一覧APIのレスポンスJSON。results[].id を1行ずつ出す。
#   page-cursor                : stdin=子ブロック一覧APIのレスポンスJSON（DB query結果にも流用可。
#                                 has_more/next_cursorの形はどちらも同じ）。
#                                 "has_more(true/false)\tnext_cursor" を1行出す（無ければ空文字）。
#   page-create-payload --parent P --title T : POST /v1/pages のbody JSONを1行出す。
#   md-to-batches               : stdin=デイリーMD全文。Notionブロックへ素朴変換し、
#                                 100ブロック/リクエスト上限で分割した各バッチ(JSON配列)を1行ずつ出す。
#                                 rich_textは2000字上限で分割する。空行はブロックを作らずskipする。
#   extract-id                  : stdin=任意のNotion APIレスポンスJSON。トップレベルの"id"を1行出す。
#
# サブコマンド（N3=notion-board.sh・N2=notion-inbox-pull.sh向け・DB操作）:
#   find-db-id --title T        : stdin=検索APIレスポンスJSON。object=="database"かつタイトルが
#                                 Tと完全一致するdatabaseのidを1行出す（無ければexit 1）。
#   board-db-create-payload --parent P : POST /v1/databases のbody（計画ボードの5プロパティ）を出す。
#   inbox-db-create-payload --parent P : POST /v1/databases のbody（依頼インボックスの2プロパティ）を出す。
#   inbox-db-schema-payload      : PATCH /v1/databases/{id} のbody（properties部のみ・冪等。
#                                 旧2値DBへ「立案済」選択肢を足す移行用）を出す。
#   list-db-rows                : stdin=DB query APIレスポンスJSON。各行の "id\ttitle平文" を1行ずつ出す
#                                 （titleプロパティはtype=="title"のプロパティを自動検出。プロパティ名を
#                                 決め打ちしないため計画ボード/依頼インボックス両方で共用できる。
#                                 title文中のタブ・改行はスペースへ畳む）。
#   board-row-create-payload --db D --title T --status S --priority P --category C --next N :
#                                 POST /v1/pages（計画ボードへの新規行）のbodyを出す。
#   board-row-update-payload --title T --status S --priority P --category C --next N :
#                                 PATCH /v1/pages/{id}（計画ボード行の更新）のbody（properties部のみ）を出す。
#                                 優先/分類が空文字なら select:null（クリア）にする。
#
# サブコマンド（N3b=notion-lanes.sh「レーン実況」DB向け・列再設計v2＝統合program plan.md 方針5e）:
#   lanes-db-create-payload --parent P : POST /v1/databases のbody（レーン実況の11プロパティ）を出す。
#   lanes-db-schema-payload             : PATCH /v1/databases/{id} のbody（properties部のみ・11プロパティ
#                                 定義を再送する。既存DBに無ければ追加・あれば同一定義を上書きするだけ
#                                 なので2回実行してもプロパティは増殖しない＝差し戻し5d対応）。
#   lane-row-create-payload --db D --title T --work W --stage S --panes P --attention A --updated U
#                            --repo R --sort-order N --plan PL --kind K :
#                                 POST /v1/pages（レーン実況への新規行）のbodyを出す。
#   lane-row-update-payload --title T --work W --stage S --panes P --attention A --updated U
#                            --repo R --sort-order N --plan PL --kind K :
#                                 PATCH /v1/pages/{id}（レーン実況行の更新）のbody（properties部のみ）を
#                                 出す。段階/要注意/repo/種別が空文字ならselect:null（クリア）にする。
#   list-lane-rows               : stdin=DB query APIレスポンスJSON。各行の "id\tフォルダーパス値" を
#                                 1行ずつ出す。upsertマッチング（フォルダーパス完全一致のみ。旧形式行の
#                                 フォールバック照合は撤去済み＝キー列が空の行は遺物として呼び出し側が
#                                 archiveする）に使う。
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

RICH_TEXT_LIMIT = 2000
BLOCKS_PER_REQUEST = 100

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
TODO_RE = re.compile(r"^-\s+\[([ xX])\]\s*(.*)$")
BULLET_RE = re.compile(r"^-\s+(.*)$")


def _parse_args(argv, spec):
    # spec: {"--title": "title", "--parent": "parent"} 程度の単純な名前付き引数パーサ。
    out = {}
    i = 0
    while i < len(argv):
        tok = argv[i]
        if tok in spec and i + 1 < len(argv):
            out[spec[tok]] = argv[i + 1]
            i += 2
        else:
            i += 1
    return out


def chunk_rich_text(content):
    if not content:
        return []
    return [
        {"type": "text", "text": {"content": content[i : i + RICH_TEXT_LIMIT]}}
        for i in range(0, len(content), RICH_TEXT_LIMIT)
    ]


def md_to_blocks(text):
    blocks = []
    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        m = HEADING_RE.match(stripped)
        if m:
            level = min(len(m.group(1)), 3)
            btype = "heading_%d" % level
            blocks.append(
                {"object": "block", "type": btype, btype: {"rich_text": chunk_rich_text(m.group(2))}}
            )
            continue
        m = TODO_RE.match(stripped)
        if m:
            checked = m.group(1).lower() == "x"
            blocks.append(
                {
                    "object": "block",
                    "type": "to_do",
                    "to_do": {"rich_text": chunk_rich_text(m.group(2)), "checked": checked},
                }
            )
            continue
        m = BULLET_RE.match(stripped)
        if m:
            blocks.append(
                {
                    "object": "block",
                    "type": "bulleted_list_item",
                    "bulleted_list_item": {"rich_text": chunk_rich_text(m.group(1))},
                }
            )
            continue
        blocks.append(
            {"object": "block", "type": "paragraph", "paragraph": {"rich_text": chunk_rich_text(stripped)}}
        )
    return blocks


def cmd_md_to_batches(argv):
    text = sys.stdin.read()
    blocks = md_to_blocks(text)
    for i in range(0, len(blocks), BLOCKS_PER_REQUEST):
        print(json.dumps(blocks[i : i + BLOCKS_PER_REQUEST], ensure_ascii=False))
    return 0


def _title_of(item):
    if not isinstance(item, dict):
        return None
    if item.get("object") == "page":
        props = item.get("properties") or {}
        for v in props.values():
            if isinstance(v, dict) and v.get("type") == "title":
                return "".join(
                    t.get("plain_text", "") for t in v.get("title", []) if isinstance(t, dict)
                )
        return None
    if item.get("type") == "child_page":
        cp = item.get("child_page") or {}
        return cp.get("title")
    return None


def cmd_find_title_id(argv):
    args = _parse_args(argv, {"--title": "title"})
    title = args.get("title")
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 1
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return 1
    for item in results:
        text = _title_of(item)
        if text is not None and text == title:
            item_id = item.get("id") if isinstance(item, dict) else None
            if item_id:
                print(item_id)
                return 0
    return 1


def cmd_list_ids(argv):
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return 0
    for item in results:
        if isinstance(item, dict) and item.get("id"):
            print(item["id"])
    return 0


def cmd_page_cursor(argv):
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("false\t")
        return 0
    has_more = bool(data.get("has_more")) if isinstance(data, dict) else False
    next_cursor = data.get("next_cursor") if isinstance(data, dict) else None
    print("%s\t%s" % ("true" if has_more else "false", next_cursor or ""))
    return 0


def cmd_page_create_payload(argv):
    args = _parse_args(argv, {"--parent": "parent", "--title": "title"})
    payload = {
        "parent": {"page_id": args.get("parent", "")},
        "properties": {
            "title": {"title": [{"type": "text", "text": {"content": args.get("title", "")}}]}
        },
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_extract_id(argv):
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 1
    page_id = data.get("id") if isinstance(data, dict) else None
    if not page_id:
        return 1
    print(page_id)
    return 0


def _db_title_of(item):
    # database検索結果のtitleはpageのtitle-propertyと違い、item直下の "title" 配列（rich_text）。
    if not isinstance(item, dict) or item.get("object") != "database":
        return None
    title_arr = item.get("title")
    if not isinstance(title_arr, list):
        return None
    parts = []
    for t in title_arr:
        if not isinstance(t, dict):
            continue
        parts.append(t.get("plain_text") or (t.get("text") or {}).get("content", ""))
    return "".join(parts)


def cmd_find_db_id(argv):
    args = _parse_args(argv, {"--title": "title"})
    title = args.get("title")
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 1
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return 1
    for item in results:
        text = _db_title_of(item)
        if text is not None and text == title:
            item_id = item.get("id") if isinstance(item, dict) else None
            if item_id:
                print(item_id)
                return 0
    return 1


def cmd_board_db_create_payload(argv):
    args = _parse_args(argv, {"--parent": "parent"})
    payload = {
        "parent": {"type": "page_id", "page_id": args.get("parent", "")},
        "title": [{"type": "text", "text": {"content": "計画ボード"}}],
        "properties": {
            "計画名": {"title": {}},
            "状態": {"select": {"options": [{"name": "active"}]}},
            "優先": {"select": {"options": [{"name": "◎"}, {"name": "○"}]}},
            "次の一手": {"rich_text": {}},
            "分類": {
                "select": {
                    "options": [
                        {"name": "skill"},
                        {"name": "repo"},
                        {"name": "loop"},
                        {"name": "横断"},
                    ]
                }
            },
        },
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def _inbox_db_properties():
    # 依頼インボックスDBのプロパティ定義の正本（新規作成POSTと既存DBへの冪等スキーマ追加PATCHの
    # 両方がこれを使う。_lanes_db_properties() と同じ流儀＝2箇所に複製しない）。
    # 状態selectは「空白=下書き（プロパティ値なし・回収しない）/ 立案済=回収対象 / 回収済み」の
    # 状態機械（マルチ指揮官体制program 子03）。旧「新規」は廃止済みのためここに含めない。
    # 実測メモ（2026-07-03の実DB移行時）: ①selectに存在しない選択肢でのqueryフィルタは空でなく
    # 400 validation_errorになる（そのため旧2値DBには inbox-db-schema-payload のPATCHが先に必要）
    # ②schema PATCHにoptions配列を渡すと、渡さなかった既存オプション（旧「新規」・値の入った行
    # 0件）は一覧から消えた＝置き換え挙動。値が入っている行が居る選択肢を消す可能性があるので、
    # 既存行の状態値を確認してからPATCHすること。
    return {
        "依頼": {"title": {}},
        "状態": {"select": {"options": [{"name": "立案済"}, {"name": "回収済み"}]}},
    }


def cmd_inbox_db_create_payload(argv):
    args = _parse_args(argv, {"--parent": "parent"})
    payload = {
        "parent": {"type": "page_id", "page_id": args.get("parent", "")},
        "title": [{"type": "text", "text": {"content": "依頼インボックス"}}],
        "properties": _inbox_db_properties(),
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_inbox_db_schema_payload(argv):
    # PATCH /v1/databases/{id} 用。properties部のみ（selectオプションは追加マージ・2回実行しても
    # 増殖しない。旧2値（新規/回収済み）時代の既存DBへ「立案済」を足す移行に使う）。
    print(json.dumps({"properties": _inbox_db_properties()}, ensure_ascii=False))
    return 0


def cmd_list_db_rows(argv):
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return 0
    for item in results:
        if not isinstance(item, dict):
            continue
        props = item.get("properties") or {}
        title_text = None
        for v in props.values():
            if isinstance(v, dict) and v.get("type") == "title":
                title_text = "".join(
                    (t.get("plain_text") or (t.get("text") or {}).get("content", ""))
                    for t in v.get("title", [])
                    if isinstance(t, dict)
                )
                break
        if title_text is None:
            continue
        title_text = title_text.replace("\t", " ").replace("\n", " ").replace("\r", " ")
        row_id = item.get("id")
        if row_id:
            print("%s\t%s" % (row_id, title_text))
    return 0


def _select_or_null(value):
    return {"select": {"name": value}} if value else {"select": None}


def _board_row_properties(title, status, priority, category, next_action):
    return {
        "計画名": {"title": ([{"type": "text", "text": {"content": title}}] if title else [])},
        "状態": _select_or_null(status),
        "優先": _select_or_null(priority),
        "次の一手": {"rich_text": (chunk_rich_text(next_action) if next_action else [])},
        "分類": _select_or_null(category),
    }


_BOARD_ROW_ARG_SPEC = {
    "--title": "title",
    "--status": "status",
    "--priority": "priority",
    "--category": "category",
    "--next": "next",
}


def cmd_board_row_create_payload(argv):
    args = _parse_args(argv, dict(_BOARD_ROW_ARG_SPEC, **{"--db": "db"}))
    payload = {
        "parent": {"database_id": args.get("db", "")},
        "properties": _board_row_properties(
            args.get("title", ""), args.get("status", ""), args.get("priority", ""),
            args.get("category", ""), args.get("next", ""),
        ),
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_board_row_update_payload(argv):
    args = _parse_args(argv, _BOARD_ROW_ARG_SPEC)
    payload = {
        "properties": _board_row_properties(
            args.get("title", ""), args.get("status", ""), args.get("priority", ""),
            args.get("category", ""), args.get("next", ""),
        )
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def _lanes_db_properties():
    # レーン実況DBのプロパティ定義11本の正本（新規作成POST /databasesと、既存DBへの冪等な
    # スキーマ追加PATCH /databases/{id}の両方がこれを使う。差し戻しでrepo・並び順を追加した際、
    # 定義を2箇所に複製しない＝lanes-db-create-payload と lanes-db-schema-payload の唯一の情報源）。
    # 列再設計v2（統合program plan.md 方針5e）で「計画」「種別」を追加。「フォルダーパス」は
    # upsertキーと「パス」表示列を兼ねる（別列を増やさない）。
    return {
        "レーン名": {"title": {}},
        "計画": {"rich_text": {}},
        "種別": {"select": {"options": [{"name": "worktree"}, {"name": "main"}]}},
        "作業内容": {"rich_text": {}},
        "段階": {
            "select": {
                "options": [
                    {"name": "計画"},
                    {"name": "実装"},
                    {"name": "実装レビュー"},
                    {"name": "修正"},
                    {"name": "人間確認待ち"},
                    {"name": "完了"},
                ]
            }
        },
        "ペイン": {"rich_text": {}},
        "要注意": {
            "select": {
                "options": [
                    {"name": "なし"},
                    {"name": "人間確認待ち"},
                    {"name": "エラー"},
                    {"name": "停滞"},
                ]
            }
        },
        "更新": {"date": {}},
        "repo": {"select": {"options": []}},
        "並び順": {"number": {}},
        "フォルダーパス": {"rich_text": {}},
    }


def cmd_lanes_db_create_payload(argv):
    args = _parse_args(argv, {"--parent": "parent"})
    payload = {
        "parent": {"type": "page_id", "page_id": args.get("parent", "")},
        "title": [{"type": "text", "text": {"content": "レーン実況"}}],
        "properties": _lanes_db_properties(),
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_lanes_db_schema_payload(argv):
    # PATCH /v1/databases/{id} 用。properties部のみ（Notionはプロパティ定義を名前でマージするため、
    # 既存DBに無ければ追加・既にあれば同一定義で上書き＝2回実行してもプロパティが増殖しない）。
    print(json.dumps({"properties": _lanes_db_properties()}, ensure_ascii=False))
    return 0


def _number_or_null(value):
    if value in (None, ""):
        return {"number": None}
    return {"number": int(value)}


def _lane_row_properties(title, work, stage, panes, attention, updated, repo, sort_order, key, plan, kind):
    return {
        "レーン名": {"title": ([{"type": "text", "text": {"content": title}}] if title else [])},
        "計画": {"rich_text": (chunk_rich_text(plan) if plan else [])},
        "種別": _select_or_null(kind),
        "作業内容": {"rich_text": (chunk_rich_text(work) if work else [])},
        "段階": _select_or_null(stage),
        "ペイン": {"rich_text": (chunk_rich_text(panes) if panes else [])},
        "要注意": _select_or_null(attention),
        "更新": ({"date": {"start": updated}} if updated else {"date": None}),
        "repo": _select_or_null(repo),
        "並び順": _number_or_null(sort_order),
        "フォルダーパス": {"rich_text": (chunk_rich_text(key) if key else [])},
    }


_LANE_ROW_ARG_SPEC = {
    "--title": "title",
    "--work": "work",
    "--stage": "stage",
    "--panes": "panes",
    "--attention": "attention",
    "--updated": "updated",
    "--repo": "repo",
    "--sort-order": "sort_order",
    "--key": "key",
    "--plan": "plan",
    "--kind": "kind",
}


def cmd_lane_row_create_payload(argv):
    args = _parse_args(argv, dict(_LANE_ROW_ARG_SPEC, **{"--db": "db"}))
    payload = {
        "parent": {"database_id": args.get("db", "")},
        "properties": _lane_row_properties(
            args.get("title", ""), args.get("work", ""), args.get("stage", ""),
            args.get("panes", ""), args.get("attention", ""), args.get("updated", ""),
            args.get("repo", ""), args.get("sort_order", ""), args.get("key", ""),
            args.get("plan", ""), args.get("kind", ""),
        ),
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_lane_row_update_payload(argv):
    args = _parse_args(argv, _LANE_ROW_ARG_SPEC)
    payload = {
        "properties": _lane_row_properties(
            args.get("title", ""), args.get("work", ""), args.get("stage", ""),
            args.get("panes", ""), args.get("attention", ""), args.get("updated", ""),
            args.get("repo", ""), args.get("sort_order", ""), args.get("key", ""),
            args.get("plan", ""), args.get("kind", ""),
        )
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_list_lane_rows(argv):
    # stdin=DB query APIレスポンスJSON。各行の "id\tフォルダーパス値" を1行ずつ出す。
    # notion-lanes.sh がupsertマッチング（フォルダーパス完全一致のみ）に使う。
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return 0
    for item in results:
        if not isinstance(item, dict):
            continue
        props = item.get("properties") or {}
        key_prop = props.get("フォルダーパス") or {}
        key_val = "".join(
            (t.get("plain_text") or (t.get("text") or {}).get("content", ""))
            for t in key_prop.get("rich_text", [])
            if isinstance(t, dict)
        )
        key_val = key_val.replace("\t", " ").replace("\n", " ").replace("\r", " ")

        row_id = item.get("id")
        if row_id:
            print("%s\t%s" % (row_id, key_val))
    return 0


COMMANDS = {
    "find-title-id": cmd_find_title_id,
    "list-ids": cmd_list_ids,
    "page-cursor": cmd_page_cursor,
    "page-create-payload": cmd_page_create_payload,
    "md-to-batches": cmd_md_to_batches,
    "extract-id": cmd_extract_id,
    "find-db-id": cmd_find_db_id,
    "board-db-create-payload": cmd_board_db_create_payload,
    "inbox-db-create-payload": cmd_inbox_db_create_payload,
    "inbox-db-schema-payload": cmd_inbox_db_schema_payload,
    "list-db-rows": cmd_list_db_rows,
    "board-row-create-payload": cmd_board_row_create_payload,
    "board-row-update-payload": cmd_board_row_update_payload,
    "lanes-db-create-payload": cmd_lanes_db_create_payload,
    "lanes-db-schema-payload": cmd_lanes_db_schema_payload,
    "lane-row-create-payload": cmd_lane_row_create_payload,
    "lane-row-update-payload": cmd_lane_row_update_payload,
    "list-lane-rows": cmd_list_lane_rows,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print("usage: notion_helper.py <%s> [options]" % "|".join(COMMANDS), file=sys.stderr)
        return 2
    return COMMANDS[sys.argv[1]](sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())
