import assert from 'node:assert/strict';
import test from 'node:test';
import { selectCandidates } from '../dispatcher.js';

test('selectCandidates: capacity分だけ候補にし、残りはoverflowとしてreadyに残す', () => {
  const ready = ['a.md', 'b.md', 'c.md', 'd.md'];
  const { candidates, overflow } = selectCandidates(ready, 2);
  assert.deepEqual(candidates, ['a.md', 'b.md']);
  assert.deepEqual(overflow, ['c.md', 'd.md']);
});

test('selectCandidates: capacityがready枚数以上なら全部候補になる', () => {
  const ready = ['a.md', 'b.md'];
  const { candidates, overflow } = selectCandidates(ready, 5);
  assert.deepEqual(candidates, ['a.md', 'b.md']);
  assert.deepEqual(overflow, []);
});

test('selectCandidates: capacityが0以下なら候補は空（cap超過分は全部ready残留）', () => {
  const ready = ['a.md', 'b.md'];
  assert.deepEqual(selectCandidates(ready, 0).candidates, []);
  assert.deepEqual(selectCandidates(ready, -1).candidates, []);
  assert.deepEqual(selectCandidates(ready, -1).overflow, ready);
});

test('selectCandidates: readyが空なら候補・overflowともに空', () => {
  const { candidates, overflow } = selectCandidates([], 3);
  assert.deepEqual(candidates, []);
  assert.deepEqual(overflow, []);
});
