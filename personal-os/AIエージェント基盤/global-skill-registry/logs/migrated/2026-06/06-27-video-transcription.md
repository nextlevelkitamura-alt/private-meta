# video-transcription

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/Private/.claude/skills/video-transcription`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/video-transcription`
- 概要: 動画・音声から mlx-whisper のword timestampを使った編集用JSONを作り、LLM生成ではない字幕ブロックへ整形するSkill。
- 移行理由: repo外の旧実体へruntime symlinkが集まる構成を解消し、AIエージェント基盤のGlobal Skill正本へ集約するため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/Private/.claude/skills/video-transcription` を採用。`~/.agents` / `~/.codex` / `~/.claude` は同実体へのsymlinkだった。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。2026-06-28に旧Private rootの実行script、schema、test、関連referenceを新正本配下へ吸収し、unit test、py_compile、help表示、JSON構文確認を実施。
- 備考: 旧構成では `~/.agents` / `~/.codex` / `~/.claude` が `Private/.claude` 配下の実体へsymlinkしていた。移行後は各runtime入口から新正本へのdirect symlinkに統一。旧Private rootの `.agents` / `.claude` / `.git` は今回の吸収対象外。
