#!/usr/bin/env python3
"""単一のself-contained HTMLをtmux保持のCloudflare Quick Tunnelで表示する。"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html as html_lib
import http.server
import json
import os
import re
import shlex
import shutil
import signal
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from pathlib import Path


MAX_HTML_BYTES = 16 * 1024 * 1024  # html SkillのArtifact上限と同じ。
START_TIMEOUT_SECONDS = 55  # Quick TunnelのDNS反映待ちを含め、対話を1分以上止めない。
HTTP_TIMEOUT_SECONDS = 8
TUNNEL_START_ATTEMPTS = 3
URL_RE = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
SENSITIVE_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"Authorization\s*:\s*Bearer\s+[A-Za-z0-9._~+/=-]{12,}", re.IGNORECASE),
    re.compile(r"(?:api[_-]?key|auth[_-]?token|access[_-]?token)\s*[=:]\s*['\"][^'\"]{12,}", re.IGNORECASE),
)
CACHE_ROOT = Path.home() / "Library" / "Caches" / "Codex" / "html-preview"


def real_html_path(raw: str) -> Path:
    path = Path(raw).expanduser().resolve()
    if path.suffix.lower() not in (".html", ".htm"):
        raise ValueError("対象は .html / .htm に限ります")
    if not path.is_file():
        raise ValueError("対象HTMLが存在しません")
    if path.stat().st_size > MAX_HTML_BYTES:
        raise ValueError("対象HTMLが16MiBを超えています")
    return path


def read_html(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def title_of(text: str) -> str:
    match = TITLE_RE.search(text)
    if not match:
        raise ValueError("HTMLにtitleがありません")
    return html_lib.unescape(re.sub(r"\s+", " ", match.group(1)).strip())


def ensure_public_safe(text: str) -> None:
    for pattern in SENSITIVE_PATTERNS:
        if pattern.search(text):
            raise ValueError("認証情報らしい文字列を検出したため公開しません")


def preview_id(path: Path) -> str:
    return hashlib.sha256(str(path).encode()).hexdigest()[:12]


def runtime_paths(path: Path) -> tuple[Path, Path, Path]:
    root = CACHE_ROOT / preview_id(path)
    return root, root / "status.json", root / "tunnel.log"


def session_name(path: Path) -> str:
    return f"codex-html-{preview_id(path)}"


def serve_command(path: Path) -> list[str]:
    return [sys.executable, str(Path(__file__).resolve()), "serve", "--file", str(path)]


def atomic_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def load_json(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def require_command(name: str) -> str:
    found = shutil.which(name)
    if not found:
        raise RuntimeError(f"{name} が見つかりません")
    return found


def tmux_alive(name: str) -> bool:
    tmux = shutil.which("tmux")
    if not tmux:
        return False
    result = subprocess.run([tmux, "has-session", "-t", name], capture_output=True)
    return result.returncode == 0


def _curl_body(url: str, resolve_ip: str | None = None) -> bytes | None:
    curl = shutil.which("curl")
    if not curl:
        return None
    command = [curl, "--silent", "--show-error", "--location", "--max-time",
               str(HTTP_TIMEOUT_SECONDS), "--write-out", "\n%{http_code}"]
    host = urllib.parse.urlsplit(url).hostname
    if resolve_ip and host:
        command.extend(["--resolve", f"{host}:443:{resolve_ip}"])
    command.append(url)
    result = subprocess.run(command, capture_output=True)
    if result.returncode != 0 or b"\n" not in result.stdout:
        return None
    body, status = result.stdout.rsplit(b"\n", 1)
    if status.strip() != b"200" or len(body) > MAX_HTML_BYTES:
        return None
    return body


def _public_ipv4(host: str) -> list[str]:
    dig = shutil.which("dig")
    if not dig:
        return []
    result = subprocess.run([dig, "+short", host, "@1.1.1.1"], capture_output=True, text=True)
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines()
            if re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", line.strip())]


def verify_url(url: str, expected_title: str) -> bool:
    bodies: list[bytes | None] = [_curl_body(url)]
    host = urllib.parse.urlsplit(url).hostname
    if host and bodies[0] is None:
        bodies.extend(_curl_body(url, ip) for ip in _public_ipv4(host))
    for body in bodies:
        if body is None:
            continue
        try:
            if title_of(body.decode("utf-8")) == expected_title:
                return True
        except (UnicodeError, ValueError):
            continue
    return False


def healthy(path: Path, data: dict | None) -> bool:
    if not data or data.get("file") != str(path):
        return False
    url = data.get("url")
    title = data.get("title")
    name = data.get("tmux_session")
    return bool(url and title and name and tmux_alive(name) and verify_url(url, title_of(read_html(path))))


class OneFileHandler(http.server.BaseHTTPRequestHandler):
    file_path: Path

    def _send(self, with_body: bool) -> None:
        if self.path.split("?", 1)[0] not in ("/", "/index.html"):
            self.send_error(404)
            return
        try:
            payload = self.file_path.read_bytes()
        except OSError:
            self.send_error(500)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if with_body:
            self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        self._send(True)

    def do_HEAD(self) -> None:  # noqa: N802
        self._send(False)

    def log_message(self, _format: str, *_args: object) -> None:
        return


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def serve(path: Path) -> int:
    html_text = read_html(path)
    expected_title = title_of(html_text)
    ensure_public_safe(html_text)
    root, status_path, log_path = runtime_paths(path)
    root.mkdir(parents=True, exist_ok=True)
    OneFileHandler.file_path = path
    server = ReusableTCPServer(("127.0.0.1", 0), OneFileHandler)
    port = int(server.server_address[1])
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    cloudflared = require_command("cloudflared")
    stopping = False
    process: subprocess.Popen[str] | None = None

    def shutdown(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True
        if process and process.poll() is None:
            process.terminate()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    url = ""
    try:
        with log_path.open("a", encoding="utf-8") as log:
            for attempt in range(1, TUNNEL_START_ATTEMPTS + 1):
                process = subprocess.Popen(
                    [cloudflared, "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{port}"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )
                assert process.stdout is not None
                for line in process.stdout:
                    log.write(line)
                    log.flush()
                    match = URL_RE.search(line)
                    if match and not url:
                        url = match.group(0)
                        atomic_json(status_path, {
                            "file": str(path),
                            "title": expected_title,
                            "url": url,
                            "tmux_session": session_name(path),
                            "started_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
                        })
                    if stopping:
                        break
                code = process.wait(timeout=10)
                if stopping or url or code == 0:
                    break
                log.write(f"cloudflared quick tunnel retry {attempt}/{TUNNEL_START_ATTEMPTS}\n")
                log.flush()
                time.sleep(1)
        return process.returncode if process else 1
    except subprocess.TimeoutExpired:
        if process:
            process.kill()
        return 1
    finally:
        server.shutdown()
        server.server_close()


def stop_preview(path: Path) -> bool:
    name = session_name(path)
    tmux = shutil.which("tmux")
    existed = bool(tmux and tmux_alive(name))
    if existed and tmux:
        subprocess.run([tmux, "kill-session", "-t", name], capture_output=True)
    _, status_path, _ = runtime_paths(path)
    try:
        status_path.unlink()
    except FileNotFoundError:
        pass
    return existed


def start_preview(path: Path, public_ok: bool) -> str:
    if not public_ok:
        raise RuntimeError("外部公開の明示確認が必要です（--public-ok）")
    html_text = read_html(path)
    ensure_public_safe(html_text)
    expected_title = title_of(html_text)
    require_command("tmux")
    require_command("cloudflared")
    require_command("curl")
    _, status_path, _ = runtime_paths(path)
    current = load_json(status_path)
    if healthy(path, current):
        return str(current["url"])
    stop_preview(path)

    tmux = require_command("tmux")
    command = shlex.join(serve_command(path))
    result = subprocess.run([tmux, "new-session", "-d", "-s", session_name(path), command], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError("tmux sessionを開始できませんでした")
    deadline = time.monotonic() + START_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        data = load_json(status_path)
        if data and data.get("url") and tmux_alive(session_name(path)):
            if verify_url(str(data["url"]), expected_title):
                return str(data["url"])
        if not tmux_alive(session_name(path)):
            break
        time.sleep(2)
    stop_preview(path)
    raise RuntimeError("Cloudflare URLを検証できませんでした")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("start", "status", "stop", "serve"):
        child = sub.add_parser(name)
        child.add_argument("--file", required=True)
        if name == "start":
            child.add_argument("--public-ok", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        path = real_html_path(args.file)
        if args.command == "serve":
            return serve(path)
        if args.command == "start":
            print(start_preview(path, bool(args.public_ok)))
            return 0
        if args.command == "stop":
            print("stopped" if stop_preview(path) else "already-stopped")
            return 0
        _, status_path, _ = runtime_paths(path)
        data = load_json(status_path)
        if healthy(path, data):
            print(data["url"])
            return 0
        print("stopped")
        return 1
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"mobile-preview: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
