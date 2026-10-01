# fedi-test-harness を使った実サーバーテスト（#4379）

`test/contract/` `test/integration/` など、実サーバー（アクセストークン・SNS URL）が
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

## Mastodon DB への直接接続（重要）

mulukhiya は `Mastodon::Account < Sequel::Model(:accounts)` のように **Mastodon の
Postgres を直接読む** Sequel モデルを持つ。そのため `account` / `status` 系をはじめ
多くの実サーバーテストは、HTTP（URL+トークン）だけでなく **Mastodon の DB 接続**
（`config['/postgres/dsn']`）も必要になる（tomato-shrieker 直接経路は純 HTTP なので
この差がある）。

chubo2#48 で harness 側が **db / redis を host に公開**（`127.0.0.1:5433` /
`127.0.0.1:6380`）し、`.env.test` に接続情報を出力するようになった:

```sh
MASTODON_INFO_ACCESS_TOKEN=...   # info エージェント (config['/agent/info/token'])
MASTODON_DB_DSN=postgres://mastodon:mastodon@127.0.0.1:5433/mastodon_production
MASTODON_REDIS_DSN=redis://127.0.0.1:6380
```

`Mulukhiya::TestHarness` はこれらを読み取り、`postgres.dsn` と `agent.info.token` も
自動で配線する（DSN を差した後に Sequel のデフォルト DB を張り直す）。したがって
**`config/local.yaml` への DSN 手書きは不要**で、harness を `setup.sh` で立てて
`MULUKHIYA_HARNESS_DIR` を渡すだけで DB 依存テストまで動く。local.yaml に要るのは
harness が用意しないもの（`crypt.password` 等）のみ。

> ⚠ **かつて**「ローカル Mastodon の status は `uri` カラムが null のことがあり
> `StatusTest#test_uri` が落ちる」という既知の失敗があったが、**pooza/chubo2#48 は
> クローズ済みで再現しない**（`harness-gate` スキルの判定基準も
> 「既知例外は無い」を前提にしている）。落ちたら例外を作らず原因を切り分けること。

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

# 3. 後片付け（省略しない。下記「後片付け」）
~/repos/chubo2/fedi-test-harness/mastodon/scripts/stop.sh
```

## 手順（Misskey）

Misskey ハーネス（`fedi-test-harness/misskey`）でも同様。コントローラの選択ルール:

- `config['/controller']`（既定 `mastodon`、`config/local.yaml` で上書き可）の
  接続情報があればそれを使う。
- 設定側に接続情報が無く、利用可能な接続情報が 1 つだけなら、それを採用する。

そのため Misskey ハーネスのみを `source`（= `MISSKEY_*` だけが存在）すれば、
`config/local.yaml` を編集しなくても自動で Misskey が選択される。Mastodon と Misskey の
両方を同時に source した場合は `config['/controller']` の値が優先される。

⚠ **これはリリースゲートの取り違えの原因になる。**`harness-gate` スキル（リリースゲートとしての実走）の
「系ごとにシェルを分ける」を必ず読むこと（#4559）。

```sh
cd ~/repos/chubo2/fedi-test-harness/misskey && ./scripts/setup.sh
cd ~/repos/mulukhiya-toot-proxy
set -a; source ~/repos/chubo2/fedi-test-harness/misskey/.env.test; set +a
bundle exec rake test
~/repos/chubo2/fedi-test-harness/misskey/scripts/stop.sh   # 後片付け（省略しない）
```

## リリースゲートとしての実走（省略不可）

⚠ **手順は `harness-gate` スキル（[.claude/skills/harness-gate/SKILL.md](../.claude/skills/harness-gate/SKILL.md)）へ移した**（#4731）。
判定は **Mastodon 系・Misskey 系の両方で 0 failures / 0 errors**。⚠ 系ごとにシェルを分ける（#4559）。CI の緑はこのゲートの代わりにならない（#4503）。

## webhook 投稿経路の検証（#4428）

**`WebhookInprocessTest`** が `/mulukhiya/webhook/<digest>` の受信 → `pre_toot`
パイプライン → `sns.post` で upstream へ実投稿、までを **1 プロセスで**通す。

⚠ **puma を別に立てない。**`include Rack::Test::Methods` + `def app = WebhookController`
で Sinatra を直接叩く。harness には前段の mulukhiya が居ないので、curl 方式
（`WebhookTest#test_command`）は**構造的に検証できない**（あちらは従来どおり omit）。

### ⚠⚠ harness 側に provisioning が要る（pooza/chubo2#232）

**mulukhiya の webhook 引き当ては、アプリ名で候補を絞る**:

```sql
AND (apps.name LIKE 'mulukhiya%')   -- Mastodon / Misskey とも同じ
```

そのため harness 側に **`mulukhiya` で始まる名前のアプリ**と、それに紐づく
アクセストークンが要る。**無いと `oauth_access_tokens` / `access_token` に行があっても
候補が 0 件になり、`/mulukhiya/webhook/<digest>` は必ず 404 になる。**

| | harness が作るもの | 必要な追加 |
| --- | --- | --- |
| Mastodon | Doorkeeper アプリ `fedi-test-harness` | **名前を `mulukhiya (fedi-test-harness)` へ** |
| Misskey | ⚠ **`app` / `access_token` の行を作らない**（signup が返すのはネイティブトークン） | **両方の行を作る** |

⚠ **Misskey は `hash` 列が実トークン。**mulukhiya の `Misskey::AccessToken` は
`to_s` が `values[:hash]`、`get(token:)` が `first(hash: token)` なので、
`hash` に `.env.test` のトークンを入れる（`token` 列は使われない）。

### ⚠ テストは webhook トークンを自分で用意する

harness のアカウントは webhook トークンを持たないので、`WebhookInprocessTest#setup` が
`account.user_config.token` を入れてから `account.webhook` を取る。
⚠ **入れてから取る**（`Webhook#initialize` がそのとき `@sns.token` を固定するため）。
⚠ teardown で必ず戻す（他のテストが同じアカウントを見る）。

## 後片付け（省略しない）

**実走が終わったら、起動した系ごとに必ず `stop.sh` を回す。**開発機のメモリが厳しく、
ハーネスは常駐させない（pooza/chubo2 の fedi-test-harness README）。

```sh
~/repos/chubo2/fedi-test-harness/mastodon/scripts/stop.sh
~/repos/chubo2/fedi-test-harness/misskey/scripts/stop.sh
```

- `stop.sh` はコンテナを止めるだけで、ボリュームと `.env.test` は残す。次回は `setup.sh` で
  同じトークンのまま再開できる
- `teardown.sh` は `.env` / `.env.test` まで消す完全削除。作り直すときだけ使う

### モロヘイヤ自身の Redis もハーネスが上げ下げする

モロヘイヤのテストは Mastodon / Misskey 側とは別に、**自分用の Redis を `127.0.0.1:6379`
に要求する**（`config/application.yaml` の `redis.dsn`）。以前は開発機に常駐する
redis-server に頼っていたが、**常駐させない方針になり、ハーネスが持つ**ようにした
（chubo2 `fedi-test-harness/mulukhiya-redis/`）。

- 各系の `setup.sh` が起動し、`stop.sh` / `teardown.sh` が止める
  （もう一方の系が動いている間は残す）
- ⚠ **開発機で redis-server を手で上げない。**6379 をハーネス外の Redis が使っていると
  `setup.sh` はそこで止まる
- ⚠ 2026-09-24 には、落ちていた開発機の redis-server のせいで Misskey の実走が
  **6 failures / 155 errors**（大半が `127.0.0.1:6379` への Connection refused）になった。
  **製品の退行と読み違えない**

## 関連

- #4379（本導線）/ chubo2#31（Mastodon ハーネス）/ chubo2#44（Misskey ハーネス）
- tomato-shrieker 側の利用（切り出し案 B/C）は別途 pooza/tomato-shrieker で起票
