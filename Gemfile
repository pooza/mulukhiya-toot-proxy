source 'https://rubygems.org'
ruby '>= 4.0.2', '< 5.0'
gem 'concurrent-ruby'
gem 'dry-validation'
gem 'faye-websocket', github: 'pooza/faye-websocket-ruby'
gem 'ginseng-core', github: 'pooza/ginseng-core', branch: 'main', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', branch: 'main',
  require: 'ginseng/fediverse'
gem 'ginseng-piefed', github: 'pooza/ginseng-piefed', branch: 'main', require: 'ginseng/piefed'
gem 'ginseng-postgres', github: 'pooza/ginseng-postgres', branch: 'main'
gem 'ginseng-redis', github: 'pooza/ginseng-redis', branch: 'main', require: 'ginseng/redis'
gem 'ginseng-web', github: 'pooza/ginseng-web', branch: 'main', require: 'ginseng/web'
gem 'ginseng-youtube', github: 'pooza/ginseng-youtube', branch: 'main', require: 'ginseng/you_tube'
gem 'icalendar'
# ⚠⚠ **推移依存だが上限をこちらで持つ (#4699)。**`json` を要求している gem は
# どれも `json (>= 2.3)` のように**下限しか書いていない**ので、`bundle update` の
# たびに最新の major を掴む。5.36.0 のリリース当日に **3.0.0（前日 2026-09-07
# リリース・ダウンロード 10 万件）** を掴んだ。2.21.2 は 1,440 万件。
# 🔴 `json` は API 応答・webhook・辞書・設定の全経路で使う土台なので壊れ方が広く、
# ⚠ `rake test` 緑は根拠にならない（#4687 / postmortem-2025-10-rack32.md）。
# ⚠ 上限を外す条件は #4699。**harness 両系 + ステージング 4 台で実走してから**動かす。
gem 'json', '~> 2.21'
# JSON::Validator を app/lib/mulukhiya.rb で直に使う。ginseng-core の推移依存で
# 入ってはいるが、Bundler.require が読むのは Gemfile に書いた gem だけで、
# ginseng-core 側は Ginseng::Config が autoload された副作用で require していた。
# その副作用に頼ると、Config を触らない起動経路で NameError になる (#4509)。
gem 'json-schema'
gem 'marcel'
gem 'optparse'
gem 'parallel', '~> 2.0'
gem 'puma', '~> 8.0'
# ⚠⚠ rack / sinatra / rack-session / tilt は ginseng-web が使っていないのに宣言していた
# 依存で、版を決めているのも向こうだった。判定材料（リクエスト単位の同一性）はこちらに
# しか無いので、制約ごとこちらへ移す (#4663)。ginseng-web 側の削除は 3.0.0 で、
# ⚠ 順序は「こちらで宣言 → マージ → 向こうで削除」。先に落とすと bundle install が壊れる。
#
# 🔴 上限まで書くのは 2025-10 のトークン汚染事故のため
# (docs/archive/postmortem-2025-10-rack32.md)。異なるアカウントの投稿として送信される
# 事故で、⚠ CVE になっておらず原因も未特定なので advisory では判定できない。
# ⚠⚠ 上限を外してよい条件は #4678（同時アクセスの回帰テスト）が緑になること。
# それまで sinatra 4.3 系 / rack 3.3 系へは動かさない。
#
# ⚠⚠ **4 つとも `require: false` (#4680)。**宣言の目的は**版の制約だけ**で、ロードの
# 指示ではない。🔴 付けないと `Bundler.require` がトップレベルの sinatra
# ＝ `sinatra/main` を読み、**classic の Sinatra::Application と at_exit runner** が入る
# （モロヘイヤは controller.rb で `sinatra/base` だけを使っている）。
# ⚠ Rack::Utils / Rack::Session::Cookie / Rack::URLMap / Rack::Auth::Basic は
# `sinatra/base` 経由で入るので、`require: false` でも解決できる（実測）。
gem 'rack', '~> 3.2.5', require: false # 2026-02 の同時アクセステスト (500 req × 2 並列・不整合 0、#4055) が通った版
gem 'rack-session', '>= 2.1.1', require: false # ⚠ ginseng-web の床をそのまま移すだけ。事故との関係は無い
gem 'rspotify', github: 'pooza/rspotify', branch: 'master.pooza'
gem 'ruby-progressbar'
gem 'ruby-vips', require: 'vips'
gem 'sentry-ruby'
gem 'sentry-sidekiq'
gem 'sidekiq', '~>8.1'
gem 'sidekiq-scheduler', '~>6.0.1'
gem 'sinatra', '~> 4.2.1', require: false # 🔴 事故版は 4.2.0。4.2.1 は本番 4 台で 2026-08-09 から無事故 (#4508)
gem 'tilt', '>= 2.1.0', require: false # ⚠ ginseng-web の床をそのまま移すだけ。事故との関係は無い
group :development do
  gem 'bundler-audit'
  # RuboCop 設定の正本。本体と minitest/performance/rake プラグインもこの gem が抱える。
  # ⚠⚠ タグではなく SHA で固定する（pooza/ginseng-style#75）。タグは付け替えられる。
  gem 'ginseng-style', github: 'pooza/ginseng-style',
    ref: 'ed862dcf9550d704ee670f65a30a333a694b883a', require: false # v1.1.12
  gem 'ostruct' # https://github.com/pooza/mulukhiya-toot-proxy/issues/4229
  gem 'rack-test'
  gem 'rails-erb-lint'
  gem 'ricecream'
  # ⚠ rubocop-sequel はモロヘイヤ固有のプラグインなので、正本ではなくここに置く。
  gem 'rubocop-sequel'
  gem 'slim_lint'
  gem 'test-unit'
  gem 'timecop'
  gem 'webmock'
end
