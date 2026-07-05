#!/usr/bin/env -S npx tsx
/**
 * running/ と reviewing/ の stale card を ready へ戻す（jobctl back・削除しない）。
 * dispatcher.ts の tick から関数として呼ばれる他、単独実行もできる（tsx scripts/stale-recovery.ts）。
 * review/ は対象外（無期限に待ってよい受動キュー・loop.md参照）。
 */
import * as fs from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { listCards, cardPath, jobctlBack, appendTickLog, STALE_MS } from './common.js';

const REAP_STATES = ['running', 'reviewing'] as const;

// mv はカードの ctime だけを更新する（mtime/birthtimeは不変・実測で確認済み）ので、
// 「今の状態フォルダに入ってからの経過時間」の代理指標として使う。
export function isStale(ctimeMs: number, now: number, staleMs: number): boolean {
  return now - ctimeMs > staleMs;
}

// 副作用なしの判定だけを切り出したもの（テスト用）
export function findStale(entries: { name: string; ctimeMs: number }[], now: number, staleMs: number): string[] {
  return entries.filter((e) => isStale(e.ctimeMs, now, staleMs)).map((e) => e.name);
}

export function reapStaleCards(staleMs: number = STALE_MS, now: number = Date.now()): string[] {
  const reaped: string[] = [];
  for (const state of REAP_STATES) {
    for (const name of listCards(state)) {
      let ctimeMs: number;
      try {
        ctimeMs = fs.statSync(cardPath(state, name)).ctimeMs;
      } catch {
        continue; // 走査中に別プロセスが進めた等→スキップ（冪等）
      }
      if (!isStale(ctimeMs, now, staleMs)) continue;
      if (jobctlBack(name)) {
        reaped.push(`${state}/${name}`);
      }
      // back失敗（対象が既に無い等の競合）は無害なので無視して次へ
    }
  }
  if (reaped.length) {
    appendTickLog(`stale-reap: ${reaped.join(',')}`);
  }
  return reaped;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const reaped = reapStaleCards();
  console.log(`[ai-jobs-dispatcher:stale] reaped=${reaped.length ? reaped.join(',') : '-'}`);
}
