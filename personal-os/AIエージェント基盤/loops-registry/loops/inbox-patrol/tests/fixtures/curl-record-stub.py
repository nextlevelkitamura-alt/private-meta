#!/usr/bin/env python3
# inbox-patrol / tests / curl-record-stub.py — notion-common.sh の notion_http_call が組み立てる
# curl 引数を受け取り、実ネットワークに一切出ずに「METHOD<TAB>URL<TAB>body(改行はスペースへ畳む)」を
# $NOTION_CURL_STUB_LOG へ追記して 200/"{}" を返す記録専用stub。
# Authorizationヘッダ（トークン）は意図的に記録しない（secret規律のテストがログ全文を検査する）。
import os
import sys


def main():
    args = sys.argv[1:]
    method = "GET"
    out_file = None
    url = ""
    body = ""
    i = 0
    while i < len(args):
        a = args[i]
        if a == "-X" and i + 1 < len(args):
            method = args[i + 1]
            i += 2
            continue
        if a == "-o" and i + 1 < len(args):
            out_file = args[i + 1]
            i += 2
            continue
        if a in ("-w", "--max-time", "-H") and i + 1 < len(args):
            i += 2
            continue
        if a == "--data-binary" and i + 1 < len(args):
            p = args[i + 1]
            if p.startswith("@"):
                try:
                    with open(p[1:], encoding="utf-8") as f:
                        body = f.read()
                except OSError:
                    body = "<body-read-error>"
            else:
                body = p
            i += 2
            continue
        if a.startswith("http"):
            url = a
        i += 1

    log = os.environ.get("NOTION_CURL_STUB_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as f:
            f.write("%s\t%s\t%s\n" % (method, url, body.replace("\n", " ").replace("\t", " ")))
    if out_file:
        with open(out_file, "w", encoding="utf-8") as f:
            f.write("{}")
    sys.stdout.write("200")
    return 0


if __name__ == "__main__":
    sys.exit(main())
