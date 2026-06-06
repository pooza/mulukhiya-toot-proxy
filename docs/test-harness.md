# fedi-test-harness を使った実インスタンステスト（#4379）

`test/contract/` `test/integration/` など、実インスタンス（アクセストークン・SNS URL）が
無いとスキップされるテストを、chubo2 の
[fedi-test-harness](https://github.com/pooza/chubo2/tree/main/fedi-test-harness)
（バニラ Mastodon / Misskey のローカル環境, chubo2#31 / chubo2#44）相手に動かす手順。

## 仕組み

ハーネスの `setup.sh` は接続情報を `.env.test` に出力する:

```
MASTODON_URL=http://localhost:3000
MASTODON_ACCESS_TOKEN=xxxxxxxx...
```

`Mulukhiya::TestHarness`（[test_harness.rb](../app/lib/mulukhiya/test_harness.rb)）が
テスト起動時（`TestCase.load`）にこの接続情報を読み込み、対象コントローラの
`config['/<controller>/url']` と `config['/agent/test/token']` を上書きする。
接続情報が無ければ何もしない（従来どおりスキップ）。CI は接続情報を持たないため
影響を受けない。

接続情報の供給は 2 通り:

- **直接 ENV**（README 推奨）: `.env.test` を `source` して環境変数に展開する。
- **`MULUKHIYA_HARNESS_DIR`**: ハーネスのルートを指すと、`<controller>/.env.test`
  を自動で読み込む（直接 ENV があればそちらを優先）。

## 手順（Mastodon）

```sh
# 1. ハーネスを起動（chubo2 側、冪等）
cd ~/repos/chubo2/fedi-test-harness/mastodon
./scripts/setup.sh

# 2a. .env.test を source して実行
cd ~/repos/mulukhiya-toot-proxy
set -a; source ~/repos/chubo2/fedi-test-harness/mastodon/.env.test; set +a
bundle exec rake test
#   または個別ケース: bin/test.rb mastodon_auth_contract

# 2b. もしくはハーネスのルートを渡して実行（source 不要）
MULUKHIYA_HARNESS_DIR=~/repos/chubo2/fedi-test-harness bundle exec rake test
```

## 手順（Misskey）

Misskey ハーネス（`fedi-test-harness/misskey`）でも同様。コントローラの選択ルール:

- `config['/controller']`（既定 `mastodon`、`config/local.yaml` で上書き可）の
  接続情報があればそれを使う。
- 設定側に接続情報が無く、利用可能な接続情報が 1 つだけなら、それを採用する。

そのため Misskey ハーネスのみを `source`（= `MISSKEY_*` だけが存在）すれば、
`config/local.yaml` を編集しなくても自動で Misskey が選択される。Mastodon と Misskey の
両方を同時に source した場合は `config['/controller']` の値が優先される。

```sh
cd ~/repos/chubo2/fedi-test-harness/misskey && ./scripts/setup.sh
cd ~/repos/mulukhiya-toot-proxy
set -a; source ~/repos/chubo2/fedi-test-harness/misskey/.env.test; set +a
bundle exec rake test
```

## 後片付け

```sh
cd ~/repos/chubo2/fedi-test-harness/mastodon && ./scripts/teardown.sh
```

## 関連

- #4379（本導線）/ chubo2#31（Mastodon ハーネス）/ chubo2#44（Misskey ハーネス）
- tomato-shrieker 側の利用（切り出し案 B/C）は別途 pooza/tomato-shrieker で起票
