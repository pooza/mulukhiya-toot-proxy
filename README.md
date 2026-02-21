# mulukhiya-toot-proxy

![release](https://img.shields.io/github/v/release/pooza/mulukhiya-toot-proxy.svg)

各種ActivityPub対応サーバーへの投稿に対して、内容の更新等を行うプロキシ。通称「モロヘイヤ」。
詳細は[wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki)にて。

## 対応サーバー

- [Mastodon](https://github.com/tootsuite/mastodon)
- [Misskey](https://github.com/syuilo/misskey)

## ブランチ

| ブランチ | バージョン | 状態 |
| --- | --- | --- |
| `main` | 5.x | 開発中（デフォルト） |
| `v4` | 4.x | メンテナンス |

旧ブランチ名（`master` / `develop`）からリネーム済み（2026-02-22）。
既存の環境では一度だけブランチの切り替えが必要。以降は従来通り `git pull && bundle install` で更新できる。

### 4.x系を利用中の場合（旧 master）

```bash
git branch -m master v4
git fetch origin
git branch -u origin/v4 v4
```

### 5.x系に移行する場合（旧 develop）

```bash
git branch -m develop main
git fetch origin
git branch -u origin/main main
```

5.xへの移行には追加の設定変更が必要。[アップグレードガイド](docs/upgrade-guide-5.0.md)を参照。

## モロヘイヤに出来ること

投稿本文に対して、

- 各種短縮URLを戻し、本来のリンク先を明らかにする。
- 日本語を含んだURLを適切にエンコードし、クリックできるようにする。
- Amazonの商品URLからノイズを除去する。
- ハッシュタグ `#nowplaying` を含んでいたら、曲情報やサムネイルを挿入。
- サーバーのテーマと関係あるワードを含んでいたら、ハッシュタグを追加。
- アニメ実況支援。実況中の番組と関連したハッシュタグを追加。
- デフォルトハッシュタグを追加。

アップロードされたメディアファイルについて、

- 画像ファイルを上限ピクセルまで縮小。
- WebPに変換し、ファイルサイズを小さくする。
- サーバーが本来受け付けないメディアファイルを変換。
- メディアタイプに応じた `#image` `#video` `#audio` 等のタグを本文に挿入。

また、

- アニメ視聴記録サービス[Annict](https://annict.com/)から視聴記録を取得し、投稿する。
- ブックマークされた公開投稿を、[PieFed](https://join.piefed.social)に転送。
- 平易なPOSTで投稿を行えるwebhook。（Slack Incoming Webhook下位互換）
- ハッシュタグのRSSフィード。
- カスタムRSSフィード。
- 新規登録者へのウェルカムメッセージ。
- お知らせの念押し投稿。

等々。

## モロヘイヤをつくった経緯

プリキュアファン向けのMastodonサーバー「[キュアスタ！](https://precure.ml)」で、
ずっと前に「AmazonのURL、もっと短くならない〜？」って言われてたのを思い出して作りました。

プリキュアに加え、今はドラゴンクエストダイの大冒険のファンの為のサーバー
「[デルムリン丼](https://mstdn.delmulin.com)」「[ダイスキー](https://misskey.delmulin.com)」も運営しています。
「利用の条件」というほど強制力のあるお願いではないけど、プリキュアやダイ大にもし興味あったら
覗いてください。みんな喜びます。
