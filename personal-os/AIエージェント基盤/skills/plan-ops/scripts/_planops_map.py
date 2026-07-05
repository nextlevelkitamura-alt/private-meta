"""plan-ops 内部共有: program.md の「子計画マップ」ブロック解析。

progctl_core.py / program_lint_core.py の両方から import する。
このモジュール単体はCLIではない（アンダースコア始まりは非公開の合図）。

想定フォーマット（areas/AGENTS.md §3 コピペ用テンプレ準拠）:
  ## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新
  NN  <子計画名> … <状態>
      次: <次の一手>
      場所: plans/NN ／ 依存: <NN／―>

- ブロック見出し行 = 行頭（インデント無し）で `NN` (2桁数字) + 空白 で始まる行。
- ブロック本体行 = 見出し行の次から、次の見出し行またはセクション終端の直前まで（インデント付き）。
- 状態の区切りは " … "（半角スペース+U+2026+半角スペース）。
"""
import re

SEP = " … "  # " … "
HEADER_RE = re.compile(r"^(\d{2})(\s+)(.*)$")


class Block:
    def __init__(self, nn, start, end):
        self.nn = nn          # "07" 等の2桁文字列
        self.start = start    # 見出し行のインデックス（0-based, lines配列基準）
        self.end = end        # ブロック終端（次見出し or セクション終端。exclusive）


def read_lines(path):
    with open(path, encoding="utf-8") as f:
        return f.readlines()  # keepends=True相当（readlinesは常に改行を保持する）


def heading_level(line):
    m = re.match(r"^(#+)[ \t]", line)
    return len(m.group(1)) if m else 0


def find_section(lines, heading_prefix):
    """heading_prefix で前方一致する見出し行を探し、(見出し行index, 本文開始index, 本文終端index) を返す。
    見つからなければ None。終端は次の同レベル以上の見出し行、または末尾。
    """
    for i, line in enumerate(lines):
        lv = heading_level(line)
        if lv == 0:
            continue
        text = line.strip()
        text = re.sub(r"^#+\s*", "", text).strip()
        if text.startswith(heading_prefix):
            level = lv
            end = len(lines)
            for j in range(i + 1, len(lines)):
                lv2 = heading_level(lines[j])
                if lv2 != 0 and lv2 <= level:
                    end = j
                    break
            return i, i + 1, end
    return None


def find_blocks(lines, body_start, body_end):
    """[body_start, body_end) の範囲からNNブロック一覧を返す（見出し行はインデント無し）。"""
    headers = []
    for i in range(body_start, body_end):
        m = HEADER_RE.match(lines[i])
        if m:
            headers.append((m.group(1), i))
    blocks = []
    for idx, (nn, start) in enumerate(headers):
        end = headers[idx + 1][1] if idx + 1 < len(headers) else body_end
        blocks.append(Block(nn, start, end))
    return blocks


def get_state(header_line):
    """見出し行から状態テキストを取り出す（' … ' より後ろ全部・改行除く）。見つからなければNone。"""
    idx = header_line.find(SEP)
    if idx < 0:
        return None
    return header_line[idx + len(SEP):].rstrip("\n")


def find_field_line(lines, block, label):
    """block本体（ヘッダ除く）から `label` (例 '次:') で始まる行のindexを返す（無ければNone）。"""
    for i in range(block.start + 1, block.end):
        stripped = lines[i].lstrip(" \t")
        if stripped.startswith(label):
            return i
    return None


def field_value(lines, idx, label):
    """find_field_lineで見つけた行から、labelの後ろの値を取り出す（改行除く）。"""
    stripped = lines[idx].lstrip(" \t")
    return stripped[len(label):].strip().rstrip("\n") if idx is not None else None
