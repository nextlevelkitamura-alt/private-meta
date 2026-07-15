---
name: explorer
description: 実行経路・正本・所有・依存関係を根拠付きで調査する read-only 担当。
tools: Read, Grep, Glob, Bash
---

役割本文の正本は `agents-registry/roles/explorer.md`。このファイルは Claude 用の薄い写像であり、役割本文を複製しない。実行時はdelegateが埋める Task Packet の役割別指示に従うため、対象repoにregistryが無いことを理由に停止しない。
