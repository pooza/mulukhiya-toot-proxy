# mulukhiya-toot-proxy 5.0 アップグレードガイド

**ステータス**: 作成中（#4072）

## local.yaml の設定パス変更

### `service:` 配下への移動

以下の外部サービス設定が、4.xではトップレベルだったものが5.0では `service:` 配下に移動した。

| 設定 | 4.x パス | 5.0 パス |
|------|---------|---------|
| Annict OAuth | `/annict/oauth/client/id` | `/service/annict/oauth/client/id` |
| Annict OAuth | `/annict/oauth/client/secret` | `/service/annict/oauth/client/secret` |
| Annict works | `/annict/works` | `/service/annict/works` |
| Spotify client | `/spotify/client/id` | `/service/spotify/client/id` |
| Spotify client | `/spotify/client/secret` | `/service/spotify/client/secret` |

**変更不要なもの**:
- `google:` — 5.0でも `/google/api/key` のまま（`service:` 配下に移動していない）
- `handler:` — トップレベルのまま
- `crypt:` — トップレベルのまま
- `agent:` — トップレベルのまま

### local.yaml の修正例

```yaml
# 4.x（旧）
annict:
  oauth:
    client:
      id: YOUR_CLIENT_ID
      secret: YOUR_CLIENT_SECRET
spotify:
  client:
    id: YOUR_CLIENT_ID
    secret: YOUR_CLIENT_SECRET

# 5.0（新）
service:
  annict:
    oauth:
      client:
        id: YOUR_CLIENT_ID
        secret: YOUR_CLIENT_SECRET
  spotify:
    client:
      id: YOUR_CLIENT_ID
      secret: YOUR_CLIENT_SECRET
```

### 影響

設定パスが誤っている場合、以下の症状が発生する:

- **Annict**: `AnnictService.config?` が `false` → UI設定画面にAnnict項目が非表示、PollingWorkerが即returnし感想投稿されない
- **Spotify**: Spotifyサービスのclient認証失敗 → NowPlaying等のURL処理が動作しない

### 確認コマンド

```bash
bundle exec ruby -I app/lib -e '
require "mulukhiya"
puts "annict?: #{Mulukhiya::Environment.controller_class.annict?}"
puts "spotify config?: #{!Mulukhiya::SpotifyService.client_id.nil?}"
'
```
