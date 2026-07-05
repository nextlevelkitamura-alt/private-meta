#!/usr/bin/env -S npx tsx
/**
 * ai-jobs headless dispatcher.
 *
 * launchd がこのファイルを1分ごとに起動する（loop.md参照）。
 * 各tick: ready を ls（中身は解析しない）→ cap の空きぶんだけ claim → claim後に担当を読み、
 * 対応する headless AI CLI をバックグラウンド起動して即終了する。cap 超過分は ready に残る。
 * 起動の wrap（lock書込→trap解放→ログ）は参照実装 nextlevel-dispatcher.ts の launchTask と同方式。
 */
import { spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  AIJOBS_BASE,
  CAP,
  STALE_MS,
  LOG_DIR,
  appendTickLog,
  buildWorkerCommand,
  cardPath,
  countActiveLocks,
  ensureDirs,
  isCardLockActive,
  jobctlBack,
  jobctlClaim,
  listCards,
  lockPath,
  readAssignee,
  renderWorkerPrompt,
  shellQuote,
} from './common.js';
import { reapStaleCards } from './stale-recovery.js';

const SHELL = '/bin/zsh';

// ready を古い順（mtime昇順）に並べる。ls自体は中身を見ない（ai-jobs/AGENTS.md §1 の発見規約）。
export function listReadyCardsByAge(): string[] {
  const names = listCards('ready');
  const withStat = names.map((name) => {
    let mtimeMs = 0;
    try {
      mtimeMs = fs.statSync(cardPath('ready', name)).mtimeMs;
    } catch {
      // 走査中に消えた等→末尾扱い（mtimeMs=0のまま。実害はない）
    }
    return { name, mtimeMs };
  });
  withStat.sort((a, b) => a.mtimeMs - b.mtimeMs || a.name.localeCompare(b.name));
  return withStat.map((e) => e.name);
}

// capacityに応じてready候補を絞る純粋関数（テスト用に分離）
export function selectCandidates(
  readyCards: string[],
  capacity: number,
): { candidates: string[]; overflow: string[] } {
  const capped = Math.max(0, capacity);
  return { candidates: readyCards.slice(0, capped), overflow: readyCards.slice(capped) };
}

function workerLogPath(card: string): string {
  const safe = card.replace(/[^A-Za-z0-9_.-]/g, '_');
  return path.join(LOG_DIR, `worker-${safe}.log`);
}

// バックグラウンド起動して即終了。lock書込→trap解放→ログ→実行は参照実装と同じ wrap 方式。
export function spawnWorker(card: string, command: string, now: number): void {
  const lp = lockPath(card);
  const logPath = workerLogPath(card);
  const wrapped = [
    `echo "$$ ${now}" > ${shellQuote(lp)}`,
    `trap "rm -f ${shellQuote(lp)}" EXIT`,
    `echo "[$(date '+%Y-%m-%d %H:%M:%S')] start ${shellQuote(card)}" >> ${shellQuote(logPath)}`,
    // command を subshell で包む: command 自体が複合コマンド（&&/;等）でも、
    // リダイレクトが最後の1コマンドだけに掛かってログが欠落する事故を防ぐ。
    `( ${command} ) >> ${shellQuote(logPath)} 2>&1`,
    'exit_code=$?',
    `echo "[$(date '+%Y-%m-%d %H:%M:%S')] finish ${shellQuote(card)} exit=$exit_code" >> ${shellQuote(logPath)}`,
    'exit $exit_code',
  ].join('; ');

  const env = { ...process.env };
  // 入れ子session誤検知の回避（focusmap/scripts/task-runner.ts の既知パターンに合わせる）
  delete env.CLAUDECODE;
  // dispatch されたジョブセッションの印。⑤ session-daily-log hook はこれを見て二重記録を抑止する
  //（記録の住み分け: dispatched はカードが記録／ad-hoc 対話は hook が記録）。
  env.AIJOBS_RUN = '1';

  const child = spawn(SHELL, ['-lc', wrapped], {
    cwd: AIJOBS_BASE,
    detached: true,
    stdio: 'ignore',
    env,
  });
  child.unref();
}

function main(): void {
  ensureDirs();
  const now = Date.now();

  const active = countActiveLocks(now, STALE_MS);
  const capacity = CAP - active;
  const readyCards = listReadyCardsByAge();
  const { candidates, overflow } = selectCandidates(readyCards, capacity);

  const launched: string[] = [];
  const skipped: string[] = [];

  for (const card of candidates) {
    if (!jobctlClaim(card)) {
      skipped.push(`${card}:claim-failed`);
      continue;
    }
    if (isCardLockActive(card, now, STALE_MS)) {
      // 直前まで動いていたworkerのlockがまだ生きている（stale回収の誤検知等）→二重起動を避けて見送る
      skipped.push(`${card}:lock-already-active`);
      continue;
    }
    const assignee = readAssignee(cardPath('running', card));
    const command = buildWorkerCommand(assignee, renderWorkerPrompt(card));
    if (!command) {
      jobctlBack(card);
      skipped.push(`${card}:unsupported-engine(${assignee ?? 'unknown'})-back`);
      continue;
    }
    spawnWorker(card, command, now);
    launched.push(`${card}(${assignee})`);
  }

  const reaped = reapStaleCards(STALE_MS, now);

  const summary = [
    `tick ${new Date(now).toISOString()}`,
    `active=${active} capacity=${Math.max(0, capacity)}`,
    `launched=${launched.length ? launched.join(',') : '-'}`,
    `skipped=${skipped.length ? skipped.join(',') : '-'}`,
    `overflow-in-ready=${overflow.length}`,
    `reaped=${reaped.length ? reaped.join(',') : '-'}`,
  ].join(' | ');
  appendTickLog(summary);
  console.log(`[ai-jobs-dispatcher] ${summary}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
