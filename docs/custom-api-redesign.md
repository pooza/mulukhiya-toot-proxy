# カスタムAPI / カスタムフィード 設計見直し

## 背景

### 現在の仕組み

`local.yaml` の `/api/custom` および `/feed/custom` にエンドポイントを定義し、外部プロジェクトのコマンドを `Open3.capture3` で実行して結果を返す仕組み。

#### 関連ファイル

- `app/lib/mulukhiya/custom_api.rb` — エンドポイント定義・コマンド組み立て・レンダラー生成
- `app/lib/mulukhiya/command_line.rb` — `Ginseng::CommandLine` 継承、stdout解析
- `app/lib/mulukhiya/controller/api_controller.rb:538-548` — 動的ルーティング生成
- `app/lib/mulukhiya/storage/custom_api_render_storage.rb` — Redisキャッシュ
- `app/task/mulukhiya/api.rb` — rakeタスク（実行、bundle install）
- `app/lib/mulukhiya/environment.rb:171-177` — pre_start_tasksでbundle install実行

#### 実行フロー

1. GET `/mulukhiya/api/{path}` → APIController
2. `CustomAPI#create_renderer(params)` でRedisキャッシュ確認
3. キャッシュなし → `create_command` でCommandLine組み立て（`BUNDLE_GEMFILE` を外部プロジェクトに設定）
4. `Ginseng::CommandLine#exec` → `Bundler.with_unbundled_env` 内で `Open3.capture3` 実行
5. stdoutを解析（Content-Typeヘッダー + ボディに分離）、Redisにキャッシュ

### 経緯

mulukhiya-rubicure はもともと**独立したデーモン**として動作していた（モデル実装あり）。モロヘイヤに統合すれば設計がシンプルになるという目論見で組み込んだが、Bundler二重管理・`Open3.capture3`・pre_start_tasksの`bundle install`など**逆に複雑化**した。

### 現在の問題点

- **Bundler二重管理**: Puma内から `Bundler.with_unbundled_env` で別プロジェクトのBundler環境に切り替えてコマンド実行。不安定の温床
- **pre_start_tasks での bundle install**: 場当たり的に追加した仕組み（`/ruby/bundler/install: true`）
- **2026-03-08 インシデント**: 全カスタムAPIが500エラー（"Broken pipe @ rb_sys_fail_on_write"）。Puma再起動で復旧したが根本原因は未特定。詳細は下記

### 利用状況

- **カスタムAPI** (`/api/custom`): 1名のみ使用（キュアスタ！）
- **カスタムフィード** (`/feed/custom`): 2名が使用。変更時は事前確認が必要

## 方針: 独立デーモンに戻す

- もともと独立デーモンだった形に戻す（元のモデル実装あり）
- 自身のPuma（別ポート）で動作させ、nginxでルーティング
- Bundler環境の干渉が完全になくなる
- `Open3.capture3` によるプロセスforkも不要
- `pre_start_tasks` の `bundle install` 機能も廃止可能

### 検討した他の選択肢

- **Rack middleware/マウント**: 同一プロセスだがBundler問題が残る → 不採用
- **HTTP経由で独立プロセスに問い合わせ**: 実質的に独立デーモン化と同じ

### モロヘイヤ側への影響

- `custom_api.rb`, `command_line.rb`, `custom_api_render_storage.rb` の廃止または大幅簡素化
- `api_controller.rb` の動的ルーティング生成部分の削除
- `local.yaml` の `/api/custom` 設定の廃止
- カスタムフィード（`/feed/custom`）も同様の仕組み。合わせて検討

---

## 2026-03-08 Broken pipe インシデント記録

- **症状**: 全カスタムAPIが500エラー。エラーメッセージ: `"Broken pipe @ rb_sys_fail_on_write - <STDOUT>"`
- **発生条件**: mulukhiya-rubicure v2.0.2適用後（v2.0.1までは正常）
- **v2.0.2の変更**: `SeriesTool#index` で `:title` → `:key` に変更のみ（コード変更自体は原因ではない）
- **影響**: Uptime-Kuma監視、macOS iCalendar購読が全て500
- **調査結果**:
  - コマンドライン直接実行は正常
  - `bundle exec` 環境からの `Open3.capture3` も正常
  - Pumaプロセス経由でのみ失敗
  - Puma再起動で解消
  - Rubyバージョン（4.0.1）、CommandLine実装は同一
- **根本原因**: 未特定
- **仮説**:
  1. `bundle install`（pre_start_tasks）がgemを更新し、Bundlerの保存した環境と実際のgem環境がずれた
  2. `daemon(8)` によるSTDOUT閉鎖と `Open3.capture3` のパイプ管理の相互作用
  3. v2.0.2適用時の `bundle install` が完了前にPumaが再起動され、gem環境が中途半端だった
