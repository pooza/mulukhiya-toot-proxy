# Ginseng::Config 内部構造

ginseng-core の `Config` クラスの設計と注意点。過去に #4128 の原因になった落とし穴を含む。

## 基本構造

```
Ginseng::Config < Hash
```

Config 自体が Hash を継承している。

### raw（ソースファイル管理）

`raw` は **ソースファイル名** をキーとする Hash:

```ruby
raw['application']  # application.yaml の内容
raw['local']        # local.yaml の内容
raw['hostname']     # hostname.yaml の内容
raw['lib']          # lib.yaml の内容
```

### key_flatten（フラットキー展開）

`Hash.key_flatten` でネストされた YAML を `/` 区切りのフラットキーに展開し、Config 本体（Hash 部分）に格納する。

```
application.yaml:
  mastodon:
    capabilities:
      repost: true

→ self['/mastodon/capabilities/repost'] = true
```

**リーフノードのみ**が格納される。中間パス（`/mastodon/capabilities` 等）はキーとして存在しない。

## self[] の挙動

```ruby
self[key]  # → 値を返す or ConfigError を raise
```

- flattened keys を検索し、見つからなければ `ConfigError` を raise（ginseng-core `config.rb:57-69`）
- deprecated aliases（`raw['deprecated']`）も自動的にチェックする

### 中間パスは動作しない

`key_flatten` はリーフのみ生成するため、中間パスへのアクセスは `ConfigError` になる:

```ruby
self['/mastodon/capabilities']  # => ConfigError!（キーとして存在しない）
self['/mastodon/capabilities/repost']  # => true（リーフなので OK）
```

### sub_hash で中間パスからサブハッシュを取得

中間パスのサブツリーが必要な場合は `Mulukhiya::Config#sub_hash` を使う（`app/lib/mulukhiya/config.rb:102-104`）:

```ruby
config.sub_hash('/misskey/capabilities')
# => { 'repost' => true, 'react' => true, ... }
```

内部では `keys(prefix)` で直下の子キーを列挙し、各リーフを `self[]` で取得して Hash に再構成している。

## よくある落とし穴

### rescue {} で ConfigError を握りつぶさない

```ruby
# 危険: キーが存在してもエラー時に空ハッシュが返る
result = config['/some/key'] rescue {}

# 安全: ConfigError を明示的に rescue する
begin
  result = config['/some/key']
rescue Ginseng::ConfigError
  result = default_value
end
```

`rescue {}` は **全ての例外**を捕捉するため、キーが存在するのに別の原因でエラーが起きた場合にも空ハッシュを返してしまう。#4128 の原因。

### raw.dig はファイル名→YAML構造のアクセスのみ

```ruby
raw.dig('application', 'package')  # OK: ファイル名 → トップレベルキー
raw.dig('local', 'capabilities')   # OK（ただし application.yaml のマージ前の値）

# raw のキーはファイル名であり、YAML のネスト構造ではない
raw.dig('mastodon', 'capabilities')  # => nil（'mastodon' はファイル名ではない）
```

### nodeinfo 循環呼び出しに注意

nodeinfo 取得が Config アクセスのトリガーになり、さらに Config アクセスが nodeinfo を呼ぶ循環が起きうる。詳細は [postmortem-2026-03-nodeinfo.md](postmortem-2026-03-nodeinfo.md) を参照。
