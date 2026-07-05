import unittest
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_DIR / "scripts"))

from build_caption_blocks import build_caption_blocks


class BuildCaptionBlocksTest(unittest.TestCase):
    def test_builds_caption_blocks_from_units_without_ai(self):
        units = [
            {"id": "u000001", "start": 0.10, "end": 0.40, "text": "今日は"},
            {"id": "u000002", "start": 0.42, "end": 0.70, "text": "Codex"},
            {"id": "u000003", "start": 0.72, "end": 0.95, "text": "が"},
            {"id": "u000004", "start": 0.96, "end": 1.35, "text": "スマホに"},
            {"id": "u000005", "start": 1.36, "end": 1.80, "text": "来た"},
            {"id": "u000006", "start": 2.45, "end": 2.90, "text": "話です"},
        ]

        captions = build_caption_blocks(
            units,
            min_chars=4,
            max_chars=18,
            min_duration=0.8,
            max_duration=3.0,
            silence_gap=0.5,
        )

        self.assertEqual(len(captions), 2)
        self.assertEqual(captions[0]["start"], 0.10)
        self.assertEqual(captions[0]["end"], 1.80)
        self.assertEqual(
            captions[0]["unit_ids"],
            ["u000001", "u000002", "u000003", "u000004", "u000005"],
        )
        self.assertEqual(captions[0]["raw_text"], "今日はCodexがスマホに来た")
        self.assertEqual(captions[1]["start"], 2.45)
        self.assertEqual(captions[1]["end"], 2.90)

    def test_does_not_leave_particle_as_own_block(self):
        units = [
            {"id": "u000001", "start": 0.0, "end": 0.5, "text": "Codex"},
            {"id": "u000002", "start": 0.5, "end": 0.7, "text": "が"},
            {"id": "u000003", "start": 0.7, "end": 1.2, "text": "来た"},
            {"id": "u000004", "start": 1.8, "end": 2.2, "text": "話"},
        ]

        captions = build_caption_blocks(units, min_chars=4, max_chars=8, silence_gap=0.5)

        self.assertEqual(captions[0]["raw_text"], "Codexが来た")
        self.assertNotEqual(captions[0]["raw_text"], "Codex")
        self.assertNotEqual(captions[1]["raw_text"], "が")


if __name__ == "__main__":
    unittest.main()
