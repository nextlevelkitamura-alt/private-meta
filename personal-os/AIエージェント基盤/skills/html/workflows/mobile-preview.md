# Codexスマホプレビュー

## 入力

1. 表示するHTMLの絶対path。
2. スマホ・ブラウザ・URL表示の明示依頼。

## 手順

1. 対象がself-containedなHTMLであることを確認する。
2. secret・token・認証情報・機密情報がないことを確認する。
3. `scripts/mobile_preview.py status --file "<絶対path>"` で既存URLを確認する。
4. 健全なURLがなければ `scripts/mobile_preview.py start --file "<絶対path>" --public-ok` を実行する。
5. scriptが行うHTTPS接続・HTTP 200・title一致・tmux稼働の確認がすべて通ったことを確認する。
6. 確認後にURLと「一時URL・Mac起動中に有効」を返す。

## 再利用

1. 同じHTMLの健全なURLは再利用する。
2. URLだけ残りserverが停止していれば再発行する。
3. URL文字列の存在だけを成功扱いにしない。

## 停止

1. `scripts/mobile_preview.py stop --file "<絶対path>"` を使う。
2. tmux sessionを手でkillしない。

## 失敗時

1. HTTP 200を確認できないURLは返さない。
2. tmux・cloudflared・curlが無ければ理由を示して止める。
3. 恒久公開が必要なら別の承認付き作業へ切り替える。
