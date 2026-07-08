#!/usr/bin/env python3
# renderer / tests / fixtures / notion-curl-stub.py — Notion API v1のごく一部を模したテスト用stub。
# notion-push.sh(N1) の NOTION_CURL_CMD をこのスクリプトへ差し替えることで、実APIに触らず
# search / 子ブロック一覧 / ページ作成 / ブロック追加 / ブロックarchive を検証できる。
# notion-board.sh(N3)・notion-inbox-pull.sh(N2) 向けに database 作成 / database query /
# database行(page) の作成・更新・archive も追加で模す（N1の既存route・既存挙動は一切変更しない。
# 新規elifの追加のみ）。
# 状態は NOTION_STUB_STATE_FILE（JSON）に永続化する（1テスト内の複数curl呼び出し=複数プロセス起動
# をまたいで状態を持ち回るため）。呼び出しログは NOTION_STUB_LOG_FILE に1行ずつ追記する。
# NOTION_STUB_FAIL_ARCHIVE=1: PATCH /pages/{id} のうちarchiveリクエスト(body=="archived"のみ)
# だけを400で人為的に失敗させる（notion-lanes.sh LANES_STRICT差し戻しテスト用。通常の行更新には
# 影響しない）。
#
# notion-push.sh の http_call() が組み立てる引数列は常に
#   ... -X <method> <url> ...（-Xの直後がmethod・その次がurl）
# の並びを崩さないため、このstubはその位置関係だけを頼りに method/url を取り出す
# （curl全般の汎用パーサではなく、notion-push.sh専用の割り切ったstub）。
import json
import os
import re
import sys
import uuid


def read_state(path):
    if path and os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "parent_id": "parent-fixture-id",
        "pages": {},
        "children_of": {},
        "databases": {},
        "db_rows": {},
    }


def _typed_property(value):
    # 書き込み時のproperties値（例: {"title":[...]})は型キーを省略する（実Notionの書式）が、
    # 読み出し(query)結果は実Notion同様 "type" を明示する必要がある
    # （notion_helper.py の list-db-rows / _title_of がtype=="title"で判定するため）。
    if not isinstance(value, dict):
        return value
    for t in ("title", "rich_text", "select"):
        if t in value:
            out = dict(value)
            out["type"] = t
            return out
    return value


def _typed_properties(props):
    return {k: _typed_property(v) for k, v in (props or {}).items()}


def write_state(path, state):
    if not path:
        return
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False)


def new_id(prefix):
    return "%s-%s" % (prefix, uuid.uuid4().hex[:8])


def log(path, event):
    if not path:
        return
    with open(path, "a", encoding="utf-8") as f:
        f.write(event + "\n")


def main():
    argv = sys.argv[1:]
    method = None
    url = None
    out_file = None
    body_file = None
    for i, tok in enumerate(argv):
        if tok == "-X" and i + 1 < len(argv):
            method = argv[i + 1]
            if i + 2 < len(argv):
                url = argv[i + 2]
        elif tok == "-o" and i + 1 < len(argv):
            out_file = argv[i + 1]
        elif tok == "--data-binary" and i + 1 < len(argv):
            bf = argv[i + 1]
            if bf.startswith("@"):
                body_file = bf[1:]

    body = {}
    if body_file and os.path.exists(body_file):
        try:
            with open(body_file, encoding="utf-8") as f:
                body = json.load(f)
        except Exception:
            body = {}

    state_path = os.environ.get("NOTION_STUB_STATE_FILE")
    log_path = os.environ.get("NOTION_STUB_LOG_FILE")

    force_status = os.environ.get("NOTION_STUB_FORCE_STATUS")
    if force_status:
        resp = {"object": "error", "message": "stub: forced failure"}
        if out_file:
            with open(out_file, "w", encoding="utf-8") as f:
                json.dump(resp, f, ensure_ascii=False)
        sys.stdout.write(force_status)
        return 0

    state = read_state(state_path)
    status = 200
    resp = {}

    if url is None or method is None:
        status = 400
        resp = {"object": "error", "message": "stub: bad request (no method/url)"}
    elif method == "POST" and url.endswith("/search"):
        log(log_path, "search")
        filter_value = ((body.get("filter") or {}).get("value"))
        page_size = int(body.get("page_size") or 100)
        start = int(body.get("start_cursor") or 0)
        # search_db_fillers / search_page_fillers: テストが stub_state へ明示的に整数を seed した
        # 場合だけ、本物の前にダミー件数を挿入する（2ページ目以降に本物が来る状況の再現用。
        # 差し戻し修正: notion-common.sh の /search 全ページ走査ロジックの回帰テストのため追加。
        # 未seed(既定0)なら従来どおり単一件のみ・1ページで完結し、既存テストの挙動を変えない）。
        if filter_value == "database":
            query_title = body.get("query", "")
            fillers = int(state.get("search_db_fillers", 0))
            candidates = [
                {
                    "object": "database",
                    "id": "filler-db-%03d" % i,
                    "title": [{"type": "text", "text": {"content": "filler-db-%03d" % i}, "plain_text": "filler-db-%03d" % i}],
                }
                for i in range(fillers)
            ]
            for db_id, db in state.get("databases", {}).items():
                if db.get("archived"):
                    continue
                title = db.get("title", "")
                candidates.append(
                    {
                        "object": "database",
                        "id": db_id,
                        "title": [{"type": "text", "text": {"content": title}, "plain_text": title}],
                    }
                )
        elif os.environ.get("NOTION_STUB_SEARCH_MISS") == "1":
            candidates = []
        else:
            fillers = int(state.get("search_page_fillers", 0))
            candidates = [
                {
                    "object": "page",
                    "id": "filler-page-%03d" % i,
                    "properties": {"title": {"type": "title", "title": [{"plain_text": "filler-page-%03d" % i}]}},
                }
                for i in range(fillers)
            ]
            candidates.append(
                {
                    "object": "page",
                    "id": state["parent_id"],
                    "properties": {"title": {"type": "title", "title": [{"plain_text": "Personal OS"}]}},
                }
            )
        chunk = candidates[start : start + page_size]
        has_more = (start + page_size) < len(candidates)
        next_cursor = str(start + page_size) if has_more else None
        resp = {"results": chunk, "has_more": has_more, "next_cursor": next_cursor}
    elif method == "GET" and re.search(r"/blocks/([^/?]+)/children", url):
        m = re.search(r"/blocks/([^/?]+)/children", url)
        block_id = m.group(1)
        page_size = 100
        size_m = re.search(r"page_size=(\d+)", url)
        if size_m:
            page_size = int(size_m.group(1))
        cursor_m = re.search(r"start_cursor=([^&]+)", url)
        start = int(cursor_m.group(1)) if cursor_m else 0

        # daily-notion-sync拡張: 子にDB(child_database)がぶら下がる場合も表現する
        # （notion-lanes系のstub由来だが、日付ページ配下に表A/表Bをネストする設計のfind_child_database_id
        # テストのため、databases側もchildren_ofへ登録しis_archived判定できるようにする）。
        databases = state.get("databases", {})
        child_ids = state.get("children_of", {}).get(block_id, [])

        def is_child_archived(cid):
            if cid in databases:
                return databases[cid].get("archived", False)
            return state["pages"].get(cid, {}).get("archived", False)

        active_ids = [cid for cid in child_ids if not is_child_archived(cid)]
        chunk = active_ids[start : start + page_size]
        results = []
        for cid in chunk:
            if cid in databases:
                results.append(
                    {"object": "block", "id": cid, "type": "child_database", "child_database": {"title": databases[cid].get("title", "")}}
                )
                continue
            child = state["pages"].get(cid, {})
            if child.get("is_page"):
                results.append(
                    {"object": "block", "id": cid, "type": "child_page", "child_page": {"title": child.get("title", "")}}
                )
            else:
                results.append({"object": "block", "id": cid, "type": child.get("type", "paragraph")})
        has_more = (start + page_size) < len(active_ids)
        next_cursor = str(start + page_size) if has_more else None
        resp = {"results": results, "has_more": has_more, "next_cursor": next_cursor}
        log(log_path, "list:%s:%d" % (block_id, len(results)))
    elif method == "POST" and url.endswith("/databases"):
        parent_id = (body.get("parent") or {}).get("page_id")
        title_arr = body.get("title") or []
        title = "".join((t.get("text") or {}).get("content", "") for t in title_arr)
        new_db_id = new_id("db")
        state.setdefault("databases", {})[new_db_id] = {
            "title": title, "parent_page_id": parent_id, "archived": False
        }
        if parent_id:
            state.setdefault("children_of", {}).setdefault(parent_id, []).append(new_db_id)
        resp = {"object": "database", "id": new_db_id}
        log(log_path, "create-db:%s:%s" % (title, new_db_id))
    elif method == "PATCH" and re.search(r"/databases/([^/]+)$", url):
        m = re.search(r"/databases/([^/]+)$", url)
        db_id = m.group(1)
        databases = state.get("databases", {})
        if db_id in databases:
            # プロパティ定義のスキーマ更新（名前でマージ。既存キーは上書き・無ければ追加）を模す。
            # 差し戻し5d: notion-lanes.shが毎回スキーマ冪等追加(PATCH)する回帰テスト用。
            schema = databases[db_id].setdefault("schema_properties", {})
            schema.update(body.get("properties", {}))
            resp = {"object": "database", "id": db_id}
            log(log_path, "update-db-schema:%s:%d" % (db_id, len(body.get("properties", {}))))
        else:
            status = 404
            resp = {"object": "error", "message": "stub: unknown database %s" % db_id}
    elif method == "POST" and re.search(r"/databases/([^/]+)/query$", url):
        m = re.search(r"/databases/([^/]+)/query$", url)
        db_id = m.group(1)
        page_size = int(body.get("page_size") or 100)
        start = int(body.get("start_cursor") or 0)
        filt = body.get("filter")
        rows = state.get("db_rows", {})
        matched_ids = [
            rid for rid, r in rows.items()
            if r.get("db_id") == db_id and not r.get("archived")
        ]
        if filt:
            prop = filt.get("property")
            eq = (filt.get("select") or {}).get("equals")
            matched_ids = [
                rid for rid in matched_ids
                if ((rows[rid]["properties"].get(prop) or {}).get("select") or {}).get("name") == eq
            ]
        matched_ids.sort()
        chunk = matched_ids[start : start + page_size]
        results = [
            {"object": "page", "id": rid, "properties": _typed_properties(rows[rid]["properties"])}
            for rid in chunk
        ]
        has_more = (start + page_size) < len(matched_ids)
        next_cursor = str(start + page_size) if has_more else None
        resp = {"results": results, "has_more": has_more, "next_cursor": next_cursor}
        log(log_path, "query:%s:%d" % (db_id, len(results)))
    elif method == "POST" and url.endswith("/pages") and "database_id" in (body.get("parent") or {}):
        db_id = (body.get("parent") or {}).get("database_id")
        new_row_id = new_id("row")
        state.setdefault("db_rows", {})[new_row_id] = {
            "db_id": db_id, "properties": body.get("properties", {}), "archived": False
        }
        resp = {"object": "page", "id": new_row_id}
        log(log_path, "create-row:%s:%s" % (db_id, new_row_id))
    elif method == "POST" and url.endswith("/pages"):
        parent_id = (body.get("parent") or {}).get("page_id")
        title_arr = ((body.get("properties") or {}).get("title") or {}).get("title") or []
        title = "".join((t.get("text") or {}).get("content", "") for t in title_arr)
        new_page_id = new_id("page")
        state["pages"][new_page_id] = {"is_page": True, "title": title, "archived": False}
        state.setdefault("children_of", {}).setdefault(parent_id, []).append(new_page_id)
        state["children_of"].setdefault(new_page_id, [])
        resp = {"object": "page", "id": new_page_id}
        log(log_path, "create:%s:%s" % (title, new_page_id))
    elif method == "PATCH" and re.search(r"/pages/([^/]+)$", url):
        m = re.search(r"/pages/([^/]+)$", url)
        row_id = m.group(1)
        # NOTION_STUB_FAIL_ARCHIVE=1: archiveリクエスト(body=="archived"のみ・propertiesを
        # 伴わない)だけを人為的に失敗させる（notion-lanes.shのLANES_STRICT差し戻しテスト用。
        # 通常の行更新(propertiesを伴うPATCH)には影響しない）。
        if "archived" in body and os.environ.get("NOTION_STUB_FAIL_ARCHIVE") == "1":
            status = 400
            resp = {"object": "error", "message": "stub: forced archive failure"}
            log(log_path, "archive-row-fail:%s" % row_id)
        else:
            rows = state.get("db_rows", {})
            if row_id in rows:
                if "archived" in body:
                    rows[row_id]["archived"] = bool(body["archived"])
                    log(log_path, "archive-row:%s" % row_id)
                if "properties" in body:
                    rows[row_id]["properties"].update(body["properties"])
                    log(log_path, "update-row:%s" % row_id)
                resp = {"object": "page", "id": row_id, "archived": rows[row_id]["archived"]}
            else:
                status = 404
                resp = {"object": "error", "message": "stub: unknown page %s" % row_id}
    elif method == "PATCH" and re.search(r"/blocks/([^/]+)/children$", url):
        m = re.search(r"/blocks/([^/]+)/children$", url)
        page_id = m.group(1)
        new_blocks = body.get("children", [])
        added = []
        for b in new_blocks:
            bid = new_id("block")
            btype = b.get("type")
            state["pages"][bid] = {"is_page": False, "type": btype, "archived": False, "content": b.get(btype)}
            added.append(bid)
        state.setdefault("children_of", {}).setdefault(page_id, []).extend(added)
        resp = {"results": [{"id": bid} for bid in added]}
        log(log_path, "append:%s:%d" % (page_id, len(new_blocks)))
    elif method == "PATCH" and re.search(r"/blocks/([^/]+)$", url):
        m = re.search(r"/blocks/([^/]+)$", url)
        block_id = m.group(1)
        if body.get("archived") and block_id in state["pages"]:
            state["pages"][block_id]["archived"] = True
            log(log_path, "archive:%s" % block_id)
        resp = {"object": "block", "id": block_id, "archived": True}
    else:
        status = 404
        resp = {"object": "error", "message": "stub: unmatched route %s %s" % (method, url)}

    write_state(state_path, state)

    if out_file:
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(resp, f, ensure_ascii=False)

    sys.stdout.write(str(status))
    return 0


if __name__ == "__main__":
    sys.exit(main())
