import assert from 'node:assert/strict';
import test from 'node:test';
import { findStale, isStale } from '../stale-recovery.js';

test('isStale: 閾値未満はfalse、閾値超えはtrue', () => {
  const now = 1_000_000;
  const staleMs = 1000;
  assert.equal(isStale(now - 999, now, staleMs), false);
  assert.equal(isStale(now - 1001, now, staleMs), true);
});

test('findStale: 閾値を超えたcardだけを名前で返す', () => {
  const now = 1_000_000;
  const staleMs = 1000;
  const entries = [
    { name: 'fresh.md', ctimeMs: now - 500 },
    { name: 'stale-1.md', ctimeMs: now - 5000 },
    { name: 'stale-2.md', ctimeMs: now - 1001 },
  ];
  assert.deepEqual(findStale(entries, now, staleMs), ['stale-1.md', 'stale-2.md']);
});

test('findStale: 該当なしなら空配列', () => {
  const now = 1_000_000;
  const entries = [{ name: 'fresh.md', ctimeMs: now - 10 }];
  assert.deepEqual(findStale(entries, now, 1000), []);
});
