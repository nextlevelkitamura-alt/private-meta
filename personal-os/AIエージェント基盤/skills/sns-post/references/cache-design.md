# cache-design — ローカルキャッシュ仕様

スプシ正本 + ローカルキャッシュの整合性を保つための仕様。

## 原則

**スプシが唯一の真実、キャッシュは一時的な複製**

```
              ┌─────────────────┐
              │   スプシ（正）    │
              └────────┬────────┘
                       │
          read         │ write（即時）
       ┌──────────────┴──────────────┐
       │                              │
       ▼                              ▼
   キャッシュチェック              キャッシュ無効化
   ├ TTL内 → cacheから             & 直後に再fetch
   └ TTL超 → スプシfetch→cache保存
```

## なぜこの設計か

- **書き込みは必ずスプシから**: cache だけ書いてスプシ忘れる事故を構造的に不可能にする
- **読み込みは TTL 制御**: 毎回スプシ叩くのは遅い。3分 TTL で人体感覚に合うバランス
- **書き込み直後は強制 refresh**: 書いた直後の値を確実に cache に反映する
- **iPhone 等の手動編集**: TTL を超えた次のモード起動で自動反映される

## キャッシュ保存場所

```
~/.claude/skills/sns-post/cache/
├── account-management-{env}.json   ← アカウント管理シート全体（env=fukugyou or honyou）
├── stock-{accountName}.json        ← ネタ帳（アカウント別）
└── meta.json                       ← 各キャッシュの fetchedAt / version
```

`{env}` は config.spreadsheetId をハッシュ化した識別子（副業/本業を取り違えないため）。

## TTL ルール

| 操作 | 動作 |
|---|---|
| read（TTL 内） | cache から返す |
| read（TTL 超過） | スプシ fetch → cache 上書き → 返す |
| write | スプシ更新 → 直後にスプシ re-fetch → cache 上書き |
| 強制 refresh | TTL 無視してスプシ fetch |

**TTL = 3 分**（180 秒）

## 強制リフレッシュのタイミング

以下のタイミングは TTL 無視して必ず最新を取る:

- `/sns-post` 起動直後（毎セッション最初の 1 回）
- mode-loop 開始時
- mode-account-tend 開始時
- mode-growth フローB（分析）開始時
- ユーザーが「最新で」「リロードして」「同期して」と発話
- 別端末（iPhone 等）で手動編集した可能性が高いと判断した時

## キャッシュ破損対策

起動時に `meta.json` を読み:
- `version` フィールドがスキルバージョンと不一致 → cache 全削除して再構築
- JSON パースエラー → 該当ファイル削除して再構築
- `fetchedAt` が無い → 強制 refresh

## meta.json の構造

```json
{
  "version": "2.0.0",
  "entries": {
    "account-management-fukugyou": {
      "fetchedAt": "2026-05-04T12:34:56+09:00",
      "spreadsheetId": "1Prq..."
    },
    "stock-hiro_ai_dx": {
      "fetchedAt": "2026-05-04T12:30:00+09:00",
      "spreadsheetId": "1Prq..."
    }
  }
}
```

## 関数 API（cache.ts）

```ts
import { CacheKey, CacheData } from './cache-types';

// 読み込み（TTL を尊重）
export async function read<T>(
  key: CacheKey,
  fetcher: () => Promise<T>,
  opts?: { force?: boolean; ttlSec?: number }
): Promise<T>;

// 書き込み（呼び出し側はスプシ更新後にこれを呼ぶ）
export async function refresh<T>(
  key: CacheKey,
  fetcher: () => Promise<T>
): Promise<T>;

// 無効化（即時削除）
export async function invalidate(key: CacheKey): Promise<void>;
export async function invalidateAll(): Promise<void>;
```

## 使用パターン（必須）

```ts
// ✅ Read: cache.read() を必ず通す
const data = await cache.read('account-management', () => fetchFromSheet());

// ✅ Write: スプシ更新 → cache.refresh() で再fetch
await sheetsUpdate(...);
await cache.refresh('account-management', () => fetchFromSheet());

// ❌ 禁止: cache を直接書き換える
fs.writeFileSync(cachePath, JSON.stringify(modifiedData));  // 構造的に許可しない
```

## .gitignore

`~/.claude/skills/sns-post/cache/` 配下は **gitignore 対象**。
グローバルスキルが git 管理されていない場合でも、誤って commit されないよう .gitignore を配置する:

```gitignore
# ~/.claude/skills/sns-post/cache/.gitignore
*
!.gitignore
```

## 関連ファイル

- 実装: `scripts/sns-post/src/cache.ts`
- 利用側: `scripts/sns-post/src/account-config.ts` / `stock.ts` / 各 mode-*.md
- 正本: `references/account-edit-spec.md`（スプシ正本の根拠）
