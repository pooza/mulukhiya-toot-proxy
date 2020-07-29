# mulukhiya-toot-proxy

![release](https://img.shields.io/github/v/release/pooza/mulukhiya-toot-proxy.svg)
![test](https://github.com/pooza/mulukhiya-toot-proxy/workflows/test/badge.svg)

各種ActivityPub対応インスタンスへの投稿に対して、内容の更新等を行うプロキシ。通称「モロヘイヤ」。  
詳細は[wiki](https://github.com/pooza/mulukhiya-toot-proxy/wiki)にて。

## 対応インスタンス
- [Mastodon](https://github.com/tootsuite/mastodon)
- [Misskey](https://github.com/syuilo/misskey)
- [Dolphin](https://github.com/syuilo/dolphin)
- [Pleroma](https://git.pleroma.social/pleroma/pleroma)
- [めいすきー](https://github.com/mei23/misskey)

## モロヘイヤに出来ること

本文に対して、

- 各種短縮URLを戻し、リンク先を明らかにする。
- 日本語を含んだURLを適切にエンコードし、クリックできるようにする。
- 貼られたURLのページにcanonical指定があったら、そのURLに置き換える。
- Amazonの商品URLからノイズを除去する。商品画像やアソシエイトタグを加える。
- ハッシュタグ `#nowplaying` を含んでいたら、曲情報やサムネイルを挿入。
- インスタンスと関係あるワードを含んでいたら、ハッシュタグを追加。
- デフォルトハッシュタグを追加。

アップロードされたメディアファイルについて、

- 画像ファイルを上限ピクセルまで縮小。
- JPEGに変換し、ファイルサイズを小さくする。
- インスタンスが本来受け付けないメディアファイルを変換。
- メディアタイプに応じた `#image` `#video` `#audio` 等のタグを本文に挿入。

また、

- 投稿をTwitterにマルチポストする。
- ローカル投稿を[GROWI](https://growi.org/)等、各種外部サービスに保存。
- 平易なPOSTで投稿を行えるwebhook。（Slack互換）
- デフォルトハッシュタグのAtomフィード。（5分ごとにキャッシュされ、IFTTT等との連携に適したもの）

等々。

## モロヘイヤをつくった経緯

プリキュア専用インスタンス「[キュアスタ！](https://precure.ml)」で、ずっと前に
「AmazonのURL、もっと短くならない〜？」って言われてたのを思い出して作りました。

「利用の条件」というほど強制力のあるお願いではないけど、プリキュアにもし興味あったら
覗いてください。みんな喜びます。
