# scheduler-design — 予約バックエンド抽象化

Buffer / API（将来）を切り替え可能にするための抽象化レイヤー仕様。

## なぜ抽象化するか

- Buffer は無料プランで **1 channel あたり 10 件**の予約上限がある
- 自社で予約サービスを開発予定 → そちらに切り替えたら **無制限**にできる
- 直接 publish.ts を書き換えると差し込みのたびに副作用が広がる
- Scheduler interface を挟めば「実装を入れ替えるだけ」で済む

## アーキテクチャ

```
┌────────────────────┐
│  mode-publish.md   │
│  mode-loop.md      │
│  mode-list.md      │
└──────────┬─────────┘
           │ schedule(post) / list() / quota()
           ▼
┌──────────────────────────┐
│   Scheduler interface    │   ← scripts/sns-post/src/scheduler/interface.ts
└─────┬─────────────┬──────┘
      │             │
      ▼             ▼
┌──────────┐  ┌──────────────┐
│ Buffer   │  │ API       │
│Scheduler │  │ (ダミー実装)   │
└──────────┘  └──────────────┘
```

## interface 定義

```ts
// scripts/sns-post/src/scheduler/interface.ts

export interface ScheduledPost {
  id: string;             // バックエンド固有の ID
  source: SchedulerSource; // "Buffer" | "API"
  channelId: string;
  text: string;
  scheduledAt: string;    // ISO8601
  imageUrl?: string;
  videoUrl?: string;
}

export type SchedulerSource = 'Buffer' | 'API';

export interface QuotaInfo {
  source: SchedulerSource;
  channelId: string;
  used: number;
  limit: number;          // -1 = 無制限
  remaining: number;      // limit - used（無制限なら Infinity）
}

export interface Scheduler {
  source: SchedulerSource;

  /** 投稿を予約する */
  schedule(input: {
    channelId: string;
    text: string;
    scheduledAt: string;
    imageUrl?: string;
    videoUrl?: string;
  }): Promise<ScheduledPost>;

  /** 予約一覧を取得 */
  list(channelId: string): Promise<ScheduledPost[]>;

  /** 残枠情報を取得 */
  quota(channelId: string): Promise<QuotaInfo>;

  /** 予約をキャンセル */
  cancel(postId: string): Promise<void>;

  /** 予約内容を更新 */
  update(postId: string, patch: Partial<ScheduledPost>): Promise<ScheduledPost>;
}
```

## 実装

### BufferScheduler（既存 publish.ts から移植）

```ts
// scripts/sns-post/src/scheduler/buffer.ts
export class BufferScheduler implements Scheduler {
  source = 'Buffer' as const;

  async schedule(input) { /* GraphQL createPost */ }
  async list(channelId) { /* GraphQL postsForChannel */ }
  async quota(channelId) {
    const posts = await this.list(channelId);
    const pending = posts.filter(p => /* status pending */).length;
    return {
      source: 'Buffer',
      channelId,
      used: pending,
      limit: 10,           // 無料プラン上限
      remaining: 10 - pending,
    };
  }
  async cancel(postId) { /* GraphQL deletePost */ }
  async update(postId, patch) { /* GraphQL updatePost */ }
}
```

### APIScheduler（ダミー実装）

```ts
// scripts/sns-post/src/scheduler/ownapi.ts

/**
 * API（自社開発の予約サービス）（開発中）。
 * サービス完成後にこのファイルを実装する。
 * 完成までは config で enabled: false にして UI から非表示にする。
 */
export class APIScheduler implements Scheduler {
  source = 'API' as const;

  async schedule(_input) {
    throw new SchedulerNotImplementedError(
      '自社予約API は開発中です。完成後に実装します。'
    );
  }
  async list(_channelId) { return []; }
  async quota(_channelId) {
    return {
      source: 'API',
      channelId: _channelId,
      used: 0,
      limit: -1,           // 無制限
      remaining: Infinity,
    };
  }
  async cancel(_postId) {
    throw new SchedulerNotImplementedError('自社予約API は開発中です。');
  }
  async update(_postId, _patch) {
    throw new SchedulerNotImplementedError('自社予約API は開発中です。');
  }
}

export class SchedulerNotImplementedError extends Error {}
```

### Factory

```ts
// scripts/sns-post/src/scheduler/index.ts

export function getScheduler(source: SchedulerSource, config: Config): Scheduler {
  switch (source) {
    case 'Buffer': return new BufferScheduler(config);
    case 'API': return new APIScheduler(config);
  }
}

export function getEnabledSchedulers(config: Config): SchedulerSource[] {
  return (config.schedulers ?? [])
    .filter(s => s.enabled !== false)
    .map(s => s.source);
}
```

## config 拡張

```json
{
  "schedulers": [
    {
      "source": "Buffer",
      "enabled": true,
      "limits": { "default": 10 }
    },
    {
      "source": "API",
      "enabled": false,
      "limits": { "default": -1 },
      "endpoint": "（サービス完成後に追加）"
    }
  ]
}
```

`accounts[]` 側でアカウント別のデフォルトを指定可能:

```json
{
  "accounts": [{
    "name": "hiro_ai_dx",
    "defaultScheduler": "Buffer",
    ...
  }]
}
```

## スプシ B 列の値

予約元の B 列値:

| 値 | 意味 |
|---|---|
| `Buffer` | BufferScheduler 経由で予約済み |
| `API` | APIScheduler 経由で予約済み |
| `Manual` | 手動で予約（過去データ等） |
| （空） | 未予約 |

## ⚠️ スプシ A列・B列 の必須セット更新（重要）

予約成功後、対象行に対して **必ず両方を atomic に書き込む**:

| 列 | 値 |
|---|---|
| A | `TRUE`（チェックON = 予約済み） |
| B | `Buffer` / `API` / `Manual`（予約元） |

**禁止パターン**:
- ❌ B だけ書いて A を `FALSE` のまま放置 — 「予約済みなのに未予約扱い」になる
- ❌ B だけ書いて A を空のまま放置 — 同上

**理由**: スプシのチェックボックス（A列）が運用上の「予約済みフラグ」。これが OFF だと別スクリプト（publish.ts 等）が再度予約処理しようとして二重予約事故になる。

実装側ヘルパー（推奨）:

```ts
// 予約成功後に必ずこのヘルパー経由で書き込む
function markAsScheduled(spreadsheetId, sheetName, rowIndex, source) {
  sheetsUpdate(spreadsheetId, `${sheetName}!A${rowIndex}`, [['TRUE']]);
  sheetsUpdate(spreadsheetId, `${sheetName}!B${rowIndex}`, [[source]]);
}
```

## モードからの呼び出しパターン

### mode-publish

```ts
const scheduler = getScheduler(account.defaultScheduler, config);
const quota = await scheduler.quota(account.channelId);

if (quota.remaining < posts.length) {
  console.warn(`残枠不足: ${quota.remaining}枠 / 投稿数 ${posts.length}件`);
  // ユーザーに分割提案
}

for (const p of posts) {
  const scheduled = await scheduler.schedule(p);
  // ⚠️ A列とB列を必ず atomic に更新（A=FALSE 残しは禁止）
  markAsScheduled(spreadsheetId, sheet, p.row, scheduled.source);
}
```

### mode-list（残枠表示）

```ts
const enabled = getEnabledSchedulers(config);
for (const source of enabled) {
  const s = getScheduler(source, config);
  const q = await s.quota(account.channelId);
  console.log(`${source}: 残${q.remaining}枠 / ${q.limit}枠`);
}
```

### mode-loop（バックエンド選択）

```ts
const enabled = getEnabledSchedulers(config);
if (enabled.length > 1) {
  // AskUserQuestion で選択
} else {
  // 唯一の有効バックエンドを自動選択
}
```

## 関連ファイル

- 実装: `scripts/sns-post/src/scheduler/{interface,buffer,ownapi,index}.ts`
- 利用側: `scripts/sns-post/src/publish.ts` / `list.ts` / `quota.ts`
- config: `references/config-schema.md`
- 残枠仕様: `scripts/sns-post/src/quota.ts`
