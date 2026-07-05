/**
 * ai-jobs-dispatcher の共通処理。dispatcher.ts と stale-recovery.ts から使う。
 *
 * ai-jobs スプール・jobctl.sh・worker-prompt.md は「どこから呼んでも同じ場所を指す」単一正本
 * （jobctl.sh 自身が同じ理由で cwd 非依存の絶対パスを固定している＝skills/plan-ops/scripts/jobctl.sh
 * の AIJOBS 変数）。ここも worktree からの実行時にずれないよう同じ絶対パスに固定する
 * （相対計算だと worktree 内の空の ai-jobs/ を見てしまい、常に絶対パス固定の jobctl.sh と食い違う）。
 * このloop自身のstate/log置き場（LOOP_DIR）だけは自分の物理位置基準でよい。
 */
import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPTS_DIR = path.dirname(fileURLToPath(import.meta.url));
export const LOOP_DIR = path.resolve(SCRIPTS_DIR, '..');

export const REPO_ROOT = '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤';
export const AIJOBS_BASE = path.join(REPO_ROOT, 'loops-registry', 'ai-jobs');
export const JOBCTL_PATH = path.join(REPO_ROOT, 'skills', 'plan-ops', 'scripts', 'jobctl.sh');
export const WORKER_PROMPT_PATH = path.join(REPO_ROOT, 'loops-registry', 'references', 'worker-prompt.md');

export const OUTPUT_DIR = path.join(LOOP_DIR, 'output');
export const LOG_DIR = path.join(OUTPUT_DIR, 'logs');
export const TICK_LOG_PATH = path.join(LOG_DIR, 'dispatcher-tick.log');

export const TMP_DIR = '/tmp';
export const LOCK_PREFIX = 'ai-jobs-dispatcher-';

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export const DEFAULT_CAP = 2;
export const DEFAULT_STALE_MS = 45 * 60 * 1000; // 45分（placeholder・要調整。loop.md参照）

export const CAP = envInt('AI_JOBS_DISPATCHER_CAP', DEFAULT_CAP);
export const STALE_MS = envInt('AI_JOBS_DISPATCHER_STALE_MS', DEFAULT_STALE_MS);

export function ensureDirs(): void {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

export function appendTickLog(line: string): void {
  ensureDirs();
  fs.appendFileSync(TICK_LOG_PATH, `${line}\n`, 'utf-8');
}

// ---- ai-jobs spool ----

export function listCards(state: string): string[] {
  const dir = path.join(AIJOBS_BASE, state);
  let entries: string[] = [];
  try {
    entries = fs.readdirSync(dir);
  } catch {
    return [];
  }
  return entries.filter((name) => !name.startsWith('.'));
}

export function cardPath(state: string, card: string): string {
  return path.join(AIJOBS_BASE, state, card);
}

function runJobctl(cmd: string, card: string): boolean {
  try {
    execFileSync('/bin/bash', [JOBCTL_PATH, cmd, card], { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'] });
    return true;
  } catch {
    return false;
  }
}

export function jobctlClaim(card: string): boolean {
  return runJobctl('claim', card);
}

export function jobctlBack(card: string): boolean {
  return runJobctl('back', card);
}

// ---- run-card の 担当 だけを読む（claim後・ai-jobs/AGENTS.md §1「掴んだ後に読む」に対応） ----

export function parseAssignee(cardContent: string): string | null {
  const match = cardContent.match(/^担当[:：]\s*(\S+)/m);
  return match ? match[1] : null;
}

export function readAssignee(cardAbsPath: string): string | null {
  try {
    return parseAssignee(fs.readFileSync(cardAbsPath, 'utf-8'));
  } catch {
    return null;
  }
}

// ---- worker prompt（worker-prompt.md への導線のみ・本文は複製しない） ----

export function renderWorkerPrompt(card: string): string {
  return [
    'あなたは ai-jobs の headless ワーカー。次の2ファイルを読み、書かれた手順どおりに実行する。',
    `1. ワーカー手順の正本: ${WORKER_PROMPT_PATH}`,
    `2. 実行する card: ${cardPath('running', card)}`,
    `ai-jobs base: ${AIJOBS_BASE}`,
    `jobctl: ${JOBCTL_PATH}`,
    'このプロンプトより上記2ファイルの記載を優先する。担当不一致・情報不足・完了条件を満たせない場合は無理に進めず jobctl back で ready に戻す。secret・token を出力・記録しない。',
  ].join('\n');
}

// ---- shell quoting（参照実装 nextlevel-dispatcher.ts と同方式） ----

export function shellQuote(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

// ---- engine別のworker起動コマンド ----

export function buildWorkerCommand(engine: string | null, prompt: string): string | null {
  if (engine === 'claude') {
    return [
      'claude',
      '-p', shellQuote(prompt),
      '--dangerously-skip-permissions',
      '--output-format', 'text',
      '--max-budget-usd', '5',
    ].join(' ');
  }
  if (engine === 'codex') {
    return [
      'codex', 'exec',
      shellQuote(prompt),
      '--sandbox', 'workspace-write',
      '--skip-git-repo-check',
    ].join(' ');
  }
  return null;
}

// ---- PID lock（参照実装 nextlevel-dispatcher.ts の isTaskRunning と同方式。card単位に一般化） ----

function sanitizeForFilename(card: string): string {
  return card.replace(/[^A-Za-z0-9_.-]/g, '_');
}

export function lockPath(card: string): string {
  return path.join(TMP_DIR, `${LOCK_PREFIX}${sanitizeForFilename(card)}.lock`);
}

function isPidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// lock ファイルを読んで生存判定。死亡/stale なら削除する（参照実装と同じ副作用）。
function readLockAliveness(lockFilePath: string, now: number, staleMs: number): boolean {
  let raw: string;
  try {
    raw = fs.readFileSync(lockFilePath, 'utf-8').trim();
  } catch {
    return false;
  }
  const [pidRaw, startedRaw] = raw.split(/\s+/);
  const pid = Number(pidRaw);
  const startedMs = Number(startedRaw);
  if (Number.isFinite(pid) && pid > 0 && isPidAlive(pid)) {
    return true;
  }
  if (Number.isFinite(startedMs) && now - startedMs < staleMs) {
    return true;
  }
  try {
    fs.unlinkSync(lockFilePath);
  } catch {
    // 既に無い（他プロセスが先に掃除した等）→無視
  }
  return false;
}

export function isCardLockActive(card: string, now: number, staleMs: number): boolean {
  return readLockAliveness(lockPath(card), now, staleMs);
}

// 現在アクティブな（このdispatcherが起動した）worker数。数えながら死亡/staleは掃除する。
export function countActiveLocks(now: number, staleMs: number): number {
  let entries: string[] = [];
  try {
    entries = fs.readdirSync(TMP_DIR);
  } catch {
    return 0;
  }
  const lockFiles = entries.filter((name) => name.startsWith(LOCK_PREFIX) && name.endsWith('.lock'));
  let count = 0;
  for (const name of lockFiles) {
    if (readLockAliveness(path.join(TMP_DIR, name), now, staleMs)) count += 1;
  }
  return count;
}
