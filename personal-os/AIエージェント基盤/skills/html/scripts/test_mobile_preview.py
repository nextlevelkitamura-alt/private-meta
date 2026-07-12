#!/usr/bin/env python3
"""mobile_preview.py のネットワーク非依存テスト。"""

import importlib.util
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).with_name("mobile_preview.py")
SPEC = importlib.util.spec_from_file_location("mobile_preview", SCRIPT)
assert SPEC and SPEC.loader
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


class MobilePreviewTests(unittest.TestCase):
    def make_html(self, body: str = "本文") -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = Path(temp.name) / "report.html"
        path.write_text(f"<!doctype html><title>報告</title><p>{body}</p>", encoding="utf-8")
        return path

    def test_title_is_required(self):
        with self.assertRaises(ValueError):
            preview.title_of("<p>本文</p>")

    def test_sensitive_bearer_is_rejected(self):
        with self.assertRaises(ValueError):
            preview.ensure_public_safe("Authorization: Bearer abcdefghijklmnop")

    def test_session_name_is_stable_per_path(self):
        path = self.make_html()
        self.assertEqual(preview.session_name(path), preview.session_name(path))
        self.assertTrue(preview.session_name(path).startswith("codex-html-"))

    def test_missing_dependency_is_rejected(self):
        with mock.patch.object(preview.shutil, "which", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "tmux"):
                preview.require_command("tmux")

    def test_handler_serves_root_and_rejects_other_paths(self):
        path = self.make_html()
        preview.OneFileHandler.file_path = path
        server = preview.ReusableTCPServer(("127.0.0.1", 0), preview.OneFileHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        base = f"http://127.0.0.1:{server.server_address[1]}"

        with urllib.request.urlopen(f"{base}/", timeout=2) as response:
            self.assertEqual(response.status, 200)
            self.assertIn(b"<title>", response.read())
        with self.assertRaises(urllib.error.HTTPError) as raised:
            urllib.request.urlopen(f"{base}/other.html", timeout=2)
        self.assertEqual(raised.exception.code, 404)
        raised.exception.close()

    def test_start_requires_public_ok(self):
        path = self.make_html()
        with self.assertRaises(RuntimeError):
            preview.start_preview(path, False)

    def test_tmux_serve_command_contains_exact_file(self):
        path = self.make_html().resolve()
        command = preview.serve_command(path)
        self.assertEqual(command[0], preview.sys.executable)
        self.assertEqual(command[2:], ["serve", "--file", str(path)])
        self.assertEqual(Path(command[1]), SCRIPT.resolve())

    @mock.patch.object(preview.subprocess, "run")
    @mock.patch.object(preview.shutil, "which", return_value="/usr/bin/curl")
    def test_curl_body_requires_http_200(self, _which, run):
        run.return_value = subprocess.CompletedProcess([], 0, stdout=b"<title>\xe5\xa0\xb1\xe5\x91\x8a</title>\n200", stderr=b"")
        self.assertIn(b"<title>", preview._curl_body("https://example.test") or b"")
        run.return_value = subprocess.CompletedProcess([], 0, stdout=b"not found\n404", stderr=b"")
        self.assertIsNone(preview._curl_body("https://example.test"))

    @mock.patch.object(preview, "_curl_body", return_value=b"<title>\xe5\x88\xa5\xe3\x81\xae\xe8\xa1\xa8\xe9\xa1\x8c</title>")
    def test_verify_url_rejects_title_mismatch(self, _curl_body):
        self.assertFalse(preview.verify_url("https://example.test", "\u5831\u544a"))

    @mock.patch.object(preview, "_public_ipv4", return_value=["104.16.230.132"])
    @mock.patch.object(preview, "_curl_body")
    def test_verify_url_uses_public_dns_fallback(self, curl_body, _public_ipv4):
        curl_body.side_effect = [None, "<!doctype html><title>報告</title>".encode()]
        self.assertTrue(preview.verify_url("https://example.test", "報告"))
        self.assertEqual(curl_body.call_count, 2)

    @mock.patch.object(preview, "verify_url", return_value=True)
    @mock.patch.object(preview, "tmux_alive", return_value=True)
    def test_healthy_requires_matching_file(self, _alive, _verify):
        path = self.make_html()
        data = {"file": str(path), "url": "https://example.invalid", "title": "報告", "tmux_session": "s"}
        self.assertTrue(preview.healthy(path, data))
        data["file"] = "/different.html"
        self.assertFalse(preview.healthy(path, data))


if __name__ == "__main__":
    unittest.main()
