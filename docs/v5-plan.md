# mulukhiya-toot-proxy v5.0 計画

**作成日**: 2026-02-13

## 目標

- 対応SNSを Mastodon系 / Misskey系 の2系統に整理し、コードベースを簡素化する
- 設定ツリーの再設計、ハンドラーパイプラインの一元化など、破壊的変更を行う
- ES Modules導入によるフロントエンドのモジュール化（ビルドツール不要）
- rack 3.2 / Sidekiq 8.1 への移行を防御策込みで進める
- テストスイートの全面見直し（不適切なテストの是正、カバレッジ向上）
- Ruby 4.0対応の準備（ginseng-*系gem更新含む）

## ブランチ・リリース戦略

| バージョン | ブランチ | 目的 | SNSサポート |
|-----------|---------|------|------------|
| 4.x | `master` | Pleroma/Meisskeyユーザーの継続サポート | Mastodon, Misskey, Pleroma, Meisskey |
| 5.0 | 新ブランチ → 将来のmaster | アーキテクチャ刷新 | Mastodon系, Misskey系 |

### 4.x系メンテナンス方針

- 脆弱性対応、bundle update
- 影響の小さな修正は5.0からバックポート
- 防御策（トークン整合性チェック等）も先行実装

### Pleroma/Meisskeyの将来

5.0ではスコープ外とするが、削除ではなく「未対応」の扱い。
対応できる余裕ができた段階で、5.x系で復活させる可能性を残す。
コード削除時にも、復活を考慮した設計判断を行う。

## 1. 対応SNSの整理

### 現状 (4.x)

4タイプ、それぞれにコントローラ/サービス/モデル/リスナーが存在。

### 5.0の構成

| 系統 | コントローラ名 | 含むSNS |
|------|--------------|---------|
| Mastodon系 | MastodonController | Mastodon, Fedibird, Akkoma |
| Misskey系 | MisskeyController | Misskey, Calckey, CherryPick, Firefish, Iceshrimp, Sharkey |

### 削除対象

- `PleromaController`, `PleromaService`, `PleromaListener`, `model/pleroma/`
- `MeisskeyController`, `MeisskeyService`, `MeisskeyListener`, `model/meisskey/`
- MongoDB関連の依存とコード（`MongoCollection`基底クラス、`MongoDSN`等）
- `ginseng-mongo` gem依存（Gemfileから除去）
- 関連テストファイル
- `config/application.yaml` 内の `pleroma:`, `meisskey:` セクション

### 設計上の注意

- Pleroma/Meisskeyのコードを物理削除する際、復活時に参照できるよう、削除コミットを明確に分離する
- Mastodon系/Misskey系の抽象化で、将来新しいSNSタイプを追加しやすい構造を意識する

## 2. アーキテクチャ刷新

### 2.1 ハンドラーパイプラインの一元化

**現状の問題**: `application.yaml`内で各SNSタイプごとにハンドラーリストがほぼコピーされている（4重 → 5.0で2重）。変更時に複数箇所の修正が必要。

**方針**: ベースパイプライン＋SNS固有オーバーライドの構造にする。

**実装済み**:

- baseパイプラインが全ハンドラの実行順の正本。SNS別設定は`exclude`で不要なものを除外するだけ
- 実行有無はハンドラ自身の`disable?`/`convertable?`で判断（設定には書かない）
- `pre_upload`/`post_upload`等もbase共通に移動。MisskeyControllerに`/api/drive/files/create`エンドポイントを追加
- nginxサンプル設定を`map`+`include`でリファクタ。meisskeyサンプルは削除

```yaml
handler:
  pipeline:
    base:
      pre_toot:
        - url_normalize
        # ... 共通ハンドラー（実行順の正本）
      pre_upload:
        - image_format_convert
        - audio_format_convert
        - video_format_convert
        - image_resize
    misskey:
      pre_toot:
        exclude:
          - itunes_image
          - spotify_image
          - you_tube_image
```

### 2.2 サービス層の共通化

**現状の問題**: `notify()`が各Serviceでほぼ同一コード。OAuth処理も重複。

**方針**:
- `notify()`を`SNSServiceMethods`に統合。SNS差分はフィールド名のみなので設定で吸収
- OAuth処理の共通化。エンドポイントの差分は設定で管理

### 2.3 リスナーの統合

Mastodon系/Misskey系の2系統のみになるため、現状のまま十分シンプル。
追加の抽象化は不要。

### 2.4 ハンドラーの見直し

対応SNSと同様、ハンドラーにも要不要の見直しが必要。

- 利用実績のないハンドラー、役割が重複するハンドラーの洗い出し
- 5.0のSNS2系統化に伴い不要になるハンドラーの特定
- 外部サービスの終了・変化に伴い形骸化したハンドラーの特定
- 結果に基づき、削除・統合・リネームを判断

具体的な対象はIssue #C-5で調査する。

## 3. 設定ツリーの再設計

### 現状の問題

1. **ハンドラー設定のキー記法が不統一**: `handler_config(:pixel)` vs `handler_config('ignore/domains')`
2. **外部サービス設定の構造が不統一**: Amazon/iTunes/Spotify/Annictで命名パターンがバラバラ
3. **機能フラグの分類なし**: バックエンド機能・UI機能・データアクセスが`features/`に混在
4. **スキーマのカバー不足**: 40以上のハンドラーのうちスキーマがあるのは21個
5. **スキーマ内のタイポ**: `sourse` → `source`

### 方針

#### 3.1 ハンドラー設定のキー記法統一

シンボル記法に統一し、ネストはYAML構造で表現する。

```ruby
# before (混在)
handler_config(:pixel)
handler_config('ignore/domains')
handler_config('word/min')

# after (統一)
handler_config(:pixel)
handler_config(:ignore, :domains)
# または設定側をフラットにする
handler_config(:ignore_domains)
```

#### 3.2 外部サービス設定の構造統一

```yaml
# 案: 共通構造
service:
  spotify:
    client:
      id: ...
      secret: ...
    urls:
      api: ...
      track: ...
  itunes:
    urls:
      api: ...
      search: ...
      lookup: ...
  annict:
    oauth:
      client_id: ...
      redirect_uri: ...
```

#### 3.3 機能フラグの分類

```yaml
# 案
mastodon:
  capabilities:        # バックエンド機能
    reaction: true
    repost: true
    streaming: true
  features:            # 有効化する機能
    webhook: true
    feed: true
    announcement: true
  data:                # データアクセス
    account_timeline: true
    favorite_tags: true
    futured_tag: true
    media_catalog: true
```

#### 3.4 スキーマの整備

- 全ハンドラーにスキーマを追加
- タイポの修正（`sourse` → `source`）
- 起動時のスキーマバリデーション強化

## 4. フロントエンド ES Modules化

### 方針

- yarn/npm等のビルドツールは導入しない
- ES Modules + importmapで、CDNのESMビルドを使用
- サーバーサイド（Slim/Ruby）でimportmapを生成

### 具体的な変更

#### 4.1 importmap導入

```yaml
# config/application.yaml
webui:
  importmap:
    vue: https://cdn.jsdelivr.net/npm/vue@3/dist/vue.esm-browser.prod.js
    axios: https://cdn.jsdelivr.net/npm/axios@1.13/dist/esm/axios.js
    js-yaml: https://cdn.jsdelivr.net/npm/js-yaml@4.1/dist/js-yaml.mjs
    # ...
```

```slim
/ fragment/assets.slim
script type='importmap'
  == importmap_json
```

#### 4.2 MulukhiyaLib等のESM化

```javascript
// before: window.MulukhiyaLib (グローバル)
// after: import { MulukhiyaLib } from '/mulukhiya/script/mulukhiya_lib.js'
export const MulukhiyaLib = { install(app) { ... } }
```

#### 4.3 各ビューのモジュール化

```slim
/ before
javascript:
  const app = Vue.createApp({ ... })
  app.use(window.MulukhiyaLib)
  app.mount('#app')

/ after
script type='module'
  | import { createApp } from 'vue'
  | import { MulukhiyaLib } from '/mulukhiya/script/mulukhiya_lib.js'
  | const app = createApp({ ... })
  | app.use(MulukhiyaLib)
  | app.mount('#app')
```

### 注意点

- グローバルビルドのみ提供のライブラリ（SweetAlert2等）はimportmap外で`<script>`読み込みを継続
- ESMビルドが存在しないライブラリの洗い出しが必要

## 5. rack 3.2 / Sidekiq 8.1 移行

### 前提

[rack-upgrade-discussion.md](rack-upgrade-discussion.md) に記録された問題への対策が必須。

### 段階的アプローチ

#### Phase 1: 防御策の実装（4.xにも先行導入）

1. 投稿前トークン整合性チェック（`verify_token_integrity!`）
2. 投稿後アカウントID検証
3. 不一致検出時のアラート送信

#### Phase 2: ginseng-web stableブランチの更新

- rack `~> 3.2` + Sinatra 4.1（または4.2）対応に改修
- `Ginseng::Web::Sinatra`クラスは維持（mainブランチとは異なる方針）
- Sidekiq `~> 8.1` の依存を解放

#### Phase 3: テスト環境での検証

- 防御策込みの状態でrack 3.2を運用テスト
- 複数ユーザー同時アクセスの再現テスト
- 問題がなければ5.0に組み込み

#### Phase 4: 本番適用

- rack 3.2 + Sidekiq 8.1で5.0リリース
- 防御コードは安全網として残す

## 6. テストの全面見直し

### 現状の問題

#### カバレッジ不足（全体約55%）

| カテゴリ | 実装数 | テスト数 | カバレッジ |
| --------- | ------ | ------- | --------- |
| ハンドラー | 54 | 40 | 74% |
| サービス | 11 | 7 | 64% |
| パーサー | 5 | 2 | 40% |
| URI | 12 | 9 | 75% |
| モデル/ユーティリティ | 50+ | 51 | 60-80% |

#### 不適切なテストの蔓延

多くのテストが「存在確認」に留まっており、振る舞いを検証していない。

```ruby
# 典型的な不適切テスト: 存在確認しかしていない
def test_recent_status
  assert_kind_of(Mastodon::Status, sns.recent_status)
end

# 本来あるべきテスト: 振る舞いの検証
def test_recent_status
  status = sns.recent_status
  assert_kind_of(Mastodon::Status, status)
  assert(status.id.positive?)
  assert(status.body.present?)
  assert(status.created_at <= Time.now)
end
```

#### 外部サービスへの直接依存

- 実アカウント・実設定がないとテストがスキップされる
- 外部APIのモック/スタブが存在しない
- CIで外部サービス依存テストの成否が不安定

#### テスト分類の問題

- 単体テスト・結合テストの区別がない
- 過去にインテグレーションテストが存在したが、設計上の問題で削除された経緯がある
- エラーパス（異常系、タイムアウト、不正入力）のテストがほぼない

### 方針

#### 6.1 不適切なテストの是正

- `kind_of?`のみ、`assert_boolean`のみのテストを洗い出し、振る舞いの検証に書き換える
- 最低限、入力に対する出力の検証を行うテストにする
- テストが何を保証しているか明確にする（テスト名の見直しも含む）

#### 6.2 外部サービスのモック導入

- 外部API呼び出しをモック/スタブ化し、CIでの安定実行を確保
- テスト用のフィクスチャデータ（レスポンスJSON等）を整備
- 実APIへの結合テストは別カテゴリとして分離（任意実行）

#### 6.3 テストカテゴリの整理

```text
test/
  unit/           # 単体テスト（モック使用、高速）
    handler/
    service/
    model/
    uri/
  integration/    # 結合テスト（ハンドラーチェーン、コントローラ経由）
  contract/       # バリデーションテスト
  external/       # 外部サービス結合テスト（CI任意実行）
```

#### 6.4 カバレッジの向上

5.0スコープ内の優先順位:

1. **ハンドラー** — 全ハンドラーにテストを追加（特にパイプライン一元化後の動作確認）
2. **サービス** — Mastodon/Misskeyサービスの振る舞いテスト（モック使用）
3. **設定** — 設定ツリー再設計後のバリデーションテスト
4. **エラーパス** — 異常系テスト（不正トークン、タイムアウト、不正入力）

#### 6.5 インテグレーションテストの再設計

過去に設計上の問題で削除された経緯があるため、再導入は慎重に行う。

- 5.0のアーキテクチャ（パイプライン一元化等）が固まった後に設計する
- テスト可能な設計を前提に、ハンドラーチェーンの入出力を明確に定義する
- 外部サービス依存を完全にモック化し、CIで安定実行できることを前提条件とする

#### 6.6 rack 3.2移行時のテスト

- 複数ユーザー同時アクセスの再現テスト（#F-5と連動）
- トークン整合性チェックの単体テスト
- スレッドセーフティの検証テスト

## 7. Ruby 4.0 準備

### Ruby 4.0の現状

- Gemfile: `ruby '>= 3.4.1', '< 5.0'` （対応済み）
- コードレベルのブロッカーなし
- 主要gemは最新版でRuby 4.0互換の見込み

### 必要な作業

1. **ginseng-*系gemのRuby 4.0対応テスト** — 最大のブロッカー
2. **MongoDB依存の除去** — 5.0で実施済みとなるため、mongo gemの互換性は不問
3. **pg gemのRuby 4.0対応版への追従**
4. Ruby 4.0リリース後に`.ruby-version`を更新

### Ruby 4.0のタイムライン

- Ruby 4.0のリリース時期次第
- 5.0リリースはRuby 4.0を待たない（3.4系でリリース、4.0は5.xで対応）
- Ruby 4.0関連の更新情報が入り次第、本計画に反映する

---

## Issue一覧

### 優先度について

**即効性があり4.xバックポートが容易なもの**を優先して着手する。
以下の一覧では各Issueに優先度を付与する。

- **P1（最優先）**: 4.xにバックポート可能。影響が小さく即効性がある
- **P2（高）**: 5.0の基盤となる作業。他のIssueがブロックされる
- **P3（通常）**: 5.0スコープ内で実施
- **P4（低）**: 余裕があれば、または外部要因待ち

### 基盤・ブランチ戦略

- [x] [#4030](https://github.com/pooza/mulukhiya-toot-proxy/issues/4030) (P2): 5.0開発ブランチの作成とCI設定
- [x] [#4024](https://github.com/pooza/mulukhiya-toot-proxy/issues/4024) (P1): 4.x系メンテナンスブランチの運用ルール策定

### SNS整理

- [x] [#4031](https://github.com/pooza/mulukhiya-toot-proxy/issues/4031) (P2): Meisskeyコントローラ/サービス/リスナー/モデルの除去
- [x] [#4032](https://github.com/pooza/mulukhiya-toot-proxy/issues/4032) (P2): MongoDB依存の完全除去（MongoCollection, MongoDSN, ginseng-mongo gem）
- [x] [#4033](https://github.com/pooza/mulukhiya-toot-proxy/issues/4033) (P2): Pleromaコントローラ/サービス/リスナー/モデルの除去
- [x] [#4034](https://github.com/pooza/mulukhiya-toot-proxy/issues/4034) (P2): application.yaml から `pleroma:`, `meisskey:` セクションの除去
- [x] [#4039](https://github.com/pooza/mulukhiya-toot-proxy/issues/4039) (P3): Pleroma/Meisskey関連テストの除去
- [x] [#4040](https://github.com/pooza/mulukhiya-toot-proxy/issues/4040) (P3): Environment クラスから `pleroma?`, `meisskey?` 等の除去・整理

### アーキテクチャ

- [x] [#4041](https://github.com/pooza/mulukhiya-toot-proxy/issues/4041) (P3): ハンドラーパイプラインのベース＋オーバーライド構造への移行
- [x] [#4025](https://github.com/pooza/mulukhiya-toot-proxy/issues/4025) (P1): `notify()` をSNSServiceMethodsに統合
- [x] [#4042](https://github.com/pooza/mulukhiya-toot-proxy/issues/4042) (P3): OAuth処理の共通化（PKCE+callback統一、infobot認証時のlocal.yaml自動更新）
- [x] [#4043](https://github.com/pooza/mulukhiya-toot-proxy/issues/4043) (P3): ハンドラーパイプライン解決ロジックの実装（Event クラス改修）
- [x] [#4035](https://github.com/pooza/mulukhiya-toot-proxy/issues/4035) (P2): ハンドラーの要不要の洗い出し（利用実績・重複・形骸化の調査）
- [x] [#4044](https://github.com/pooza/mulukhiya-toot-proxy/issues/4044) (P3): 不要ハンドラーの削除・統合（#4035の結果に基づく）

### 設定ツリー

- [x] [#4045](https://github.com/pooza/mulukhiya-toot-proxy/issues/4045) (P3): handler_config のキー記法統一
- [x] [#4046](https://github.com/pooza/mulukhiya-toot-proxy/issues/4046) (P3): 外部サービス設定の構造統一（`service:` 配下に集約）
- [x] [#4047](https://github.com/pooza/mulukhiya-toot-proxy/issues/4047) (P3): 機能フラグの分類（capabilities / features / data）
- [x] [#4026](https://github.com/pooza/mulukhiya-toot-proxy/issues/4026) (P1): 全ハンドラーのスキーマ追加・タイポ修正
- [x] [#4048](https://github.com/pooza/mulukhiya-toot-proxy/issues/4048) (P3): 起動時スキーマバリデーションの強化

### フロントエンド

- [x] [#4036](https://github.com/pooza/mulukhiya-toot-proxy/issues/4036) (P2): ESMビルドが存在しないライブラリの洗い出し
- [x] [#4049](https://github.com/pooza/mulukhiya-toot-proxy/issues/4049) (P3): importmap設定の導入（config/application.yaml + fragment/assets.slim）
- [x] [#4050](https://github.com/pooza/mulukhiya-toot-proxy/issues/4050) (P3): MulukhiyaLib の ESM化
- [x] [#4051](https://github.com/pooza/mulukhiya-toot-proxy/issues/4051) (P3): SlideUpDown, VTooltip 等のローカルコンポーネントのESM化
- [x] [#4052](https://github.com/pooza/mulukhiya-toot-proxy/issues/4052) (P3): 各ビュー（config, home, api等）の `type="module"` 化

### rack / Sidekiq

- [x] [#4027](https://github.com/pooza/mulukhiya-toot-proxy/issues/4027) (P1): 投稿前トークン整合性チェックの実装（4.xバックポート対象）
- [x] [#4028](https://github.com/pooza/mulukhiya-toot-proxy/issues/4028) (P1): 投稿後アカウントID検証の実装（4.xバックポート対象）
- [x] [#4053](https://github.com/pooza/mulukhiya-toot-proxy/issues/4053) (P3): ginseng-web stableブランチのrack 3.2対応改修
- [x] [#4054](https://github.com/pooza/mulukhiya-toot-proxy/issues/4054) (P3): Sidekiq 8.1系への依存更新
- [x] [#4055](https://github.com/pooza/mulukhiya-toot-proxy/issues/4055) (P3): rack 3.2環境での同時アクセス再現テスト（dev04/dev23検証完了、10並行×50ラウンド=500リクエスト×2、成功率100%）

### テスト

- [x] [#4029](https://github.com/pooza/mulukhiya-toot-proxy/issues/4029) (P1): 存在確認のみのテスト（kind_of?/assert_boolean）を洗い出し、一覧化
- [x] [#4037](https://github.com/pooza/mulukhiya-toot-proxy/issues/4037) (P2): 不適切なテストの振る舞い検証への書き換え
- [x] [#4038](https://github.com/pooza/mulukhiya-toot-proxy/issues/4038) (P2): 外部サービスモック基盤の導入（フィクスチャデータ整備）
- [x] [#4056](https://github.com/pooza/mulukhiya-toot-proxy/issues/4056) (P3): テストディレクトリ構造の再編（unit/integration/contract/external）
- [x] [#4057](https://github.com/pooza/mulukhiya-toot-proxy/issues/4057) (P3): 未テストハンドラーへのテスト追加
- [x] [#4058](https://github.com/pooza/mulukhiya-toot-proxy/issues/4058) (P3): Mastodon/Misskeyサービスの振る舞いテスト追加（モック使用）
- [x] [#4059](https://github.com/pooza/mulukhiya-toot-proxy/issues/4059) (P3): エラーパステスト追加（不正トークン、タイムアウト、不正入力）
- [x] [#4060](https://github.com/pooza/mulukhiya-toot-proxy/issues/4060) (P3): インテグレーションテストの再設計・実装（アーキテクチャ確定後）
- [x] [#4061](https://github.com/pooza/mulukhiya-toot-proxy/issues/4061) (P3): rack 3.2同時アクセス再現テスト（#4055と連動）

### ginseng gem メンテナンス

- [x] [#4066](https://github.com/pooza/mulukhiya-toot-proxy/issues/4066) (P3): ginseng-*系gemへの汎用拡張返却監査（5.0.0実装完了後、#4072の前に実施）

### Ruby 4.0

- [x] [#4062](https://github.com/pooza/mulukhiya-toot-proxy/issues/4062) (P4): ginseng-*系gemのRuby 4.0互換性調査・テスト（Ruby 4.0対応完了、ostruct gem追加）
- [x] [#4063](https://github.com/pooza/mulukhiya-toot-proxy/issues/4063) (P4): Ruby 4.0リリース後の対応（.ruby-version更新、CI追加）

### 新機能・過去Issue対応

- [x] [#3350](https://github.com/pooza/mulukhiya-toot-proxy/issues/3350) (P2): 新規登録時webhook対応（Mastodon: `account.approved`、Misskey: `userCreated`→共に`user_approved`イベント。dev04/dev23検証完了）
- [x] [#3740](https://github.com/pooza/mulukhiya-toot-proxy/issues/3740) (~~P2~~ クローズ): アンケート公開範囲の制御 → プロキシ層での実現が困難なため見送り
- [x] [#4067](https://github.com/pooza/mulukhiya-toot-proxy/issues/4067) (P2): ChannelNotificationHandlerの通知方法見直し（info_agent_service直接呼び出し、display_nameでメンション回避、ステージング検証完了）
- [x] [#3839](https://github.com/pooza/mulukhiya-toot-proxy/issues/3839) (P3): BlueSkyブリッジアカウント宛てリアクション通知の公開範囲引き上げ（ブリッジドメイン `bsky.brid.gy` で判定、ReplyReactionHandlerのvisibility制御。実験的機能、検証はリクエスト元ユーザーに委任）
- [ ] [#3943](https://github.com/pooza/mulukhiya-toot-proxy/issues/3943) (P3→**5.0.1**): Misskey実況デコレーションの自動剥がし（`/api/i/update`＋各ユーザートークン方式。`write:account`スコープ追加が必要。認証済みユーザーのみ対象）
- [x] [#3877](https://github.com/pooza/mulukhiya-toot-proxy/issues/3877) (P3→**スコープアウト**): Mastodon形式タグづけ復活（ActivityPub Update使用、Mastodon系限定）— 5.0.0スコープ外、5.x以降で対応
- [x] [#4068](https://github.com/pooza/mulukhiya-toot-proxy/issues/4068) (P3): CSS設計の見直し（Pico CSS導入、全ページCSS競合修正、font-size統一、未使用CSS削除。ステージング検証完了）
- [x] [#4069](https://github.com/pooza/mulukhiya-toot-proxy/issues/4069) (P3): CDN利用の見直し（jsDelivrに統一、バージョンポリシー統一、SweetAlert2 importmap化、clipboard.js除去。ステージング検証完了）
- [x] [#4070](https://github.com/pooza/mulukhiya-toot-proxy/issues/4070) (P3): OAuthスコープのdefault/infobot統合（スコープ一本化、認証ボタン統合、info_bot自動検出、admin:read除外。Mastodon/Misskey検証完了）
- [x] [#4073](https://github.com/pooza/mulukhiya-toot-proxy/issues/4073) (P3): テーマカラー取得・アクセントカラー適用（Misskey: /api/meta自動取得+フォールバック、Mastodon: 設定値。CSS custom properties `--accent-color`/`--accent-bg` で動的注入。デフォルト値 Mastodon `#6364FF`/Misskey `#86b300`。ステージング検証完了）
- [x] [#3157](https://github.com/pooza/mulukhiya-toot-proxy/issues/3157) (P1→**スコープアウト**): Annict `/@:username/records/:record_id` 形式URL対応。GraphQL APIの `Record.annictId` がURL用IDと一致しない（`episode_records.id` vs `records.id`）ためAPI側の対応待ち。実装をrevertし旧形式（`/works/:work_id/episodes/:episode_id`）に戻した

### アーキテクチャ（追加）

- [x] [#4075](https://github.com/pooza/mulukhiya-toot-proxy/issues/4075) (P3→**5.1.0**): with_indifferent_access の整理・シンボルキー統一
- [x] [#4079](https://github.com/pooza/mulukhiya-toot-proxy/issues/4079) (P3→**5.1.0**): デーモン起動プロセスの簡素化
- [ ] [#4083](https://github.com/pooza/mulukhiya-toot-proxy/issues/4083) (P3→**5.1.0**): `/crypt/salt` 設定キーの廃止（`Crypt.password` のみに統一。移行注意: webhook URLが変わるためアップグレードガイドへの記載が必要）

### テスト（5.1.0追加）

- [ ] [#4082](https://github.com/pooza/mulukhiya-toot-proxy/issues/4082) (P3→**5.1.0**): Sidekiqワーカーへのテスト追加（#4057類似。10ワーカー中3件のみテストあり、未テスト7件、disable?検証、WebMock使用）

### ドキュメント

- [x] [#4072](https://github.com/pooza/mulukhiya-toot-proxy/issues/4072): 5.0アップグレードガイドの作成（`docs/webhook-setup.md` 先行作成済み）
  - テーマ色の設定手順を記載すること（Mastodonは `config['/mastodon/theme/color']` で手動設定、MisskeyはAPIから自動取得）
- [x] [#4077](https://github.com/pooza/mulukhiya-toot-proxy/issues/4077): Sidekiqダッシュボードのnginxアクセス制限（ドキュメント追加）

### 外部プロジェクトへの貢献（余裕があれば）

- [ ] Misskey本家PR: `visibility: specified` のノートで `visibleUserIds` に含まれないユーザーへのメンション通知を抑制する。DM本文中の `@user` がメンションとして解釈され、宛先外ユーザーに `(非公開)` 通知が届く問題。モロヘイヤ側は `display_name` 使用で回避済み（`3c4bc8d6`）
