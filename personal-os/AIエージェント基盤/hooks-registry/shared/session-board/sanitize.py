#!/usr/bin/env python3
"""session routingでDBへ渡す短文の共通サニタイザー。"""
import re


_ASSIGNMENT = re.compile(
    r"(?i)(api[_-]?key|secret[_-]?key|access[_-]?key|token|secret|password|passwd|bearer|authorization)"
    r"(\s*(?::|=|\bis\b)\s*)(\S+)")
_BEARER = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}")
_KNOWN_TOKEN = re.compile(
    r"\b(?:sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"AKIA[A-Z0-9]{16}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})\b")
_CREDENTIAL_URL = re.compile(r"(?i)(https?://)[^\s/@:]+:[^\s/@]+@")
_EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
_PHONE = re.compile(r"(?<!\d)(?:\+?81[-\s]?)?0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}(?!\d)")
_PRIVATE_KEY = re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----", re.I)


def sanitize_text(value, limit=80):
    """secret・連絡先らしい値を除去し、1行・上限付きで返す。疑わしい秘密鍵は全文を捨てる。"""
    text = "" if value is None else str(value)
    if _PRIVATE_KEY.search(text):
        return "[sensitive content omitted]"
    text = _ASSIGNMENT.sub(lambda m: f"{m.group(1)}{m.group(2)}[masked]", text)
    text = _BEARER.sub("Bearer [masked]", text)
    text = _KNOWN_TOKEN.sub("[masked]", text)
    text = _CREDENTIAL_URL.sub(r"\1[masked]@", text)
    text = _EMAIL.sub("[email masked]", text)
    text = _PHONE.sub("[phone masked]", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace("|", "／").replace("<", "＜").replace(">", "＞")
    return text[:max(0, int(limit))]
