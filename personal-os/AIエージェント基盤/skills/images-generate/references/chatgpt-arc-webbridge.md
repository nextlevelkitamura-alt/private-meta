# ChatGPT × Arc × kimi-webbridge ルート（推奨・実ブラウザ）

Playwright 経由の ChatGPT 自動化はロボット判定で弾かれることが多い。
**Arc ブラウザ + kimi-webbridge 拡張**で実ブラウザを操作するルートを既定にする。

CLAUDE.md の原則「Kimi WebBridge は原則 Chrome の Profile 16」よりも、
ChatGPT に関しては **Arc ルートを優先** する（明示依頼があるため）。

---

## 0. daemon 健康確認（毎回最初）

```bash
~/.kimi-webbridge/bin/kimi-webbridge status
```

| 結果 | 対処 |
|---|---|
| `extension_connected: true` | OK、進む |
| `running: false` + PIDファイル残り | `rm -f ~/.kimi-webbridge/daemon.pid && ~/.kimi-webbridge/bin/kimi-webbridge start` |
| `extension_connected: false` | ユーザーに Arc 起動 + 拡張有効化を依頼 |

**stale PID 問題**: daemon が落ちた後に PID ファイルが残るとそのまま `start` できない。`rm -f` で削除してから start する。

---

## 1. ChatGPT タブを探す or 開く

既存タブ優先（ログインセッション流用、認証ループ回避）:

```bash
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"find_tab","args":{"url":"chatgpt.com"},"session":"job-images"}'
```

無ければ navigate:

```bash
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"navigate","args":{"url":"https://chatgpt.com/","newTab":true,"group_title":"画像生成"},"session":"job-images"}'
```

**注意**: `list_tabs` はセッション内のタブのみ返す。既存タブ検索は必ず `find_tab` を使う（セッションスコープを超えて探してくれる）。

---

## 2. 求人向け専用 GPT を使う（求人サムネのとき）

ChatGPT サイドバーに **「求人の実写サムネイルを作る」** という調整済み GPT がある。
URL: `https://chatgpt.com/g/g-699e59a8b7108191a47b2558221d6286-...`

`snapshot` で `link|@e??|求人の実写サムネイルを作る` を見つけて click すれば一発。
求人サムネ以外（SNS・スライド）なら標準 ChatGPT のまま使う。

---

## 3. プロンプト入力 + 送信

入力欄は `textbox` ロール、画面状態で `@e` ref が動くので毎回 `snapshot` で取得し直す。

```bash
# 入力欄ref取得
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"snapshot","args":{}}' \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']['tree']
def walk(n):
    if isinstance(n, list):
        for c in n: walk(c)
        return
    if not isinstance(n, dict): return
    if n.get('role') == 'textbox' and 'ChatGPT' in n.get('name',''):
        print('INPUT:', n.get('ref'))
    if n.get('role') == 'button' and 'プロンプトを送信' in n.get('name',''):
        print('SEND:', n.get('ref'))
    for c in n.get('children',[]) or []: walk(c)
walk(d)
"
```

入力（contenteditable なので `fill` がそのまま効く）:

```bash
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d @- <<'EOF'
{"action":"fill","args":{"selector":"@e114","value":"<英語プロンプト>"}}
EOF
```

送信：`name="プロンプトを送信する"` のボタン or `data-testid="send-button"`。
入力後にもう一度 snapshot して ref を取り直す（入力前は送信ボタンが disabled）。

```bash
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"click","args":{"selector":"button[data-testid=\"send-button\"]"}}'
```

---

## 4. 生成完了待ち（Monitor or run_in_background）

ChatGPT 画像生成は 30〜90 秒。`until` ループで「生成中」表示が消えるまで待つ。

```bash
until ! curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"snapshot","args":{}}' \
  | grep -qE '画像を生成中|より詳細な画像|Thinking|思考中'; do
  sleep 5
done
echo "GENERATION_DONE"
```

これを `run_in_background: true` で投げて、完了通知を待つ。
`sleep 45` のような長時間 sleep は harness にブロックされるので `until` ループ + `run_in_background` が必須。

---

## 5. 画像URL取得 → ローカルへ直接ダウンロード

ChatGPT 生成画像は `chatgpt.com/backend-api/estuary/content?...` 形式の URL に置かれる。
**evaluate 内で fetch → blob → base64** すれば認証クッキー込みで取得できる（ブラウザ経由なので CORS 不要）。

```bash
# URL取得
curl -s -m 10 -X POST http://127.0.0.1:10086/command \
  -H 'Content-Type: application/json' \
  -d '{"action":"evaluate","args":{"code":"JSON.stringify([...document.querySelectorAll(\"img\")].filter(i=>i.src.includes(\"estuary/content\")||i.src.includes(\"oaiusercontent\")||i.src.includes(\"sdmntpr\")).map(i=>({src:i.src,w:i.naturalWidth,h:i.naturalHeight,alt:i.alt})))"}}'

# ダウンロード（URLを変数に入れて）
URL="<取得したsrc>"
OUT="/Users/kitamuranaohiro/Private/仕事/scripts/job-create/output/images/generated/<filename>.png"
curl -s -m 30 -X POST http://127.0.0.1:10086/command -H 'Content-Type: application/json' \
  -d "{\"action\":\"evaluate\",\"args\":{\"code\":\"(async()=>{const r=await fetch('$URL');const b=await r.blob();const ab=await b.arrayBuffer();const u=new Uint8Array(ab);let s='';for(let i=0;i<u.length;i++)s+=String.fromCharCode(u[i]);return btoa(s);})()\"}}" \
  > /tmp/img-b64.json
python3 -c "
import json,base64
d=json.load(open('/tmp/img-b64.json'))
open('$OUT','wb').write(base64.b64decode(d['data']['value']))
print('saved')
"
```

---

## 6. 複数枚を連続生成するときのコツ

- **同じ ChatGPT スレッドを使い回す**（毎回新規チャットを開かない）。専用 GPT のシステムプロンプトと参照画像が引き継がれる
- 入力欄の `@e` ref は1件送信するたびにズレる → 毎回 snapshot で取り直す
- 1件目完了 → 画像保存 → 次のプロンプト入力 → 送信 → 完了待ち → 保存 の直列で進める
- 5件以上まとめて生成する場合は `data/prompts.json` 形式でリスト化して、ループで回す

### ヘルパー関数例（zsh / bash）

```bash
chatgpt_get_input_ref() {
  curl -s -m 10 -X POST http://127.0.0.1:10086/command \
    -H 'Content-Type: application/json' \
    -d '{"action":"snapshot","args":{}}' \
    | python3 -c "import sys,json;d=json.load(sys.stdin)['data']['tree']
def w(n):
  if isinstance(n,list):
    for c in n:w(c)
    return
  if not isinstance(n,dict):return
  if n.get('role')=='textbox' and 'ChatGPT' in n.get('name',''):print(n.get('ref'));return
  for c in n.get('children',[]) or []:w(c)
w(d)"
}

chatgpt_send() {
  local PROMPT="$1"
  local REF=$(chatgpt_get_input_ref)
  curl -s -m 10 -X POST http://127.0.0.1:10086/command -H 'Content-Type: application/json' \
    -d "{\"action\":\"fill\",\"args\":{\"selector\":\"$REF\",\"value\":$(jq -Rs . <<<"$PROMPT")}}" >/dev/null
  sleep 1
  curl -s -m 10 -X POST http://127.0.0.1:10086/command -H 'Content-Type: application/json' \
    -d '{"action":"click","args":{"selector":"button[data-testid=\"send-button\"]"}}' >/dev/null
}
```

---

## よくある失敗

| 症状 | 原因 / 対処 |
|---|---|
| `fill: Uncaught` | 古い `@e` ref を使った。snapshot を取り直して新しい ref で fill |
| `session "X" has no tab` | 同じ session 名で別タブが死んでいる。`find_tab` を使うか別 session 名にする |
| daemon HTTP 接続失敗 | stale PID。`rm ~/.kimi-webbridge/daemon.pid && start` |
| 画像URLが見つからない | スクロールで隠れてる、または生成失敗。screenshot 撮って確認 |
| 「Please update the Kimi WebBridge extension」 | 拡張が古い。Arc で更新 |

---

## 関連 Skill との関係

- このルートが既定。`images-generate` SKILL.md の Step 0 で「ChatGPT ブラウザ生成」を選んだ場合はこのフローを使う
- Playwright (`scripts/job-create/src/index.ts generate-images --engine chatgpt`) はフォールバック扱い。bot 判定でほぼ通らない
- Gemini ルートは別。並列高速・抽象イラスト用
