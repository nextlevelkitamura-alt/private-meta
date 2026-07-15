# md — デイリーMarkdown層

- デイリーpath解決、行parse・描画、生存照合、flock、原子的置換を所有する。
- Turso、HTTP、keychain、secretへ依存しない。
- 行形式と既存CLIの意味は変えない。`board.py` がこの層を調停する。
- `CLAUDE.md` はこのファイルへの相対symlinkにする。
