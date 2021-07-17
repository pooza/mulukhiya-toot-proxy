# mulukhiya-toot-proxy

![release](https://img.shields.io/github/v/release/pooza/mulukhiya-toot-proxy.svg)
![test](https://github.com/pooza/mulukhiya-toot-proxy/workflows/test/badge.svg)

各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。通称「モロヘイヤ」。  
詳細は[wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki)にて。

## 対応インスタンス

- [Mastodon](https://github.com/tootsuite/mastodon)
- [Misskey](https://github.com/syuilo/misskey)
  - [Groundpolis](https://github.com/Groundpolis/Groundpolis)での動作報告あり。
- [Pleroma](https://git.pleroma.social/pleroma/pleroma)
- [めいすきー](https://github.com/mei23/misskey)

## モロヘイヤに出来ること

トゥート/ノート/チャットの本文に対して、

- 各種短縮URLを戻し、本来のリンク先を明らかにする。
- 日本語を含んだURLを適切にエンコードし、クリックできるようにする。
- 貼られたURLのページにcanonical指定があったら、そのURLに置き換える。
- Amazonの商品URLからノイズを除去する。
- ハッシュタグ `#nowplaying` を含んでいたら、曲情報やサムネイルを挿入。
- インスタンスと関係あるワードを含んでいたら、ハッシュタグを追加。
- アニメ実況支援。実況中の番組と関連したハッシュタグを追加。
- デフォルトハッシュタグを追加。

アップロードされたメディアファイルについて、

- 画像ファイルを上限ピクセルまで縮小。
- JPEGに変換し、ファイルサイズを小さくする。
- インスタンスが本来受け付けないメディアファイルを変換。
- メディアタイプに応じた `#image` `#video` `#audio` 等のタグを本文に挿入。

また、

- アニメ視聴記録サービス[Annict](https://annict.jp/)から視聴記録を取得し、投稿する。
- ローカル投稿を[Dropbox](https://dropbox.com/)等、各種外部サービスに保存。
- ブックマークされた公開投稿を、[Lemmy](https://join.lemmy.ml/)に転送。
- 平易なPOSTで投稿を行えるwebhook。（Slack Incoming Webhook下位互換）
- ハッシュタグのAtomフィード。
- 新規登録者へのウェルカムメッセージ。

等々。

## モロヘイヤをつくった経緯

プリキュアファン向けのMastodonインスタンス「[キュアスタ！](https://precure.ml)」で、
ずっと前に「AmazonのURL、もっと短くならない〜？」って言われてたのを思い出して作りました。

プリキュアに加え、今はドラゴンクエストダイの大冒険のファンの為のインスタンス
「[デルムリン丼](https://mstdn.delmulin.com)」も運営しています。  
「利用の条件」というほど強制力のあるお願いではないけど、プリキュアやダイ大にもし興味あったら
覗いてください。みんな喜びます。
