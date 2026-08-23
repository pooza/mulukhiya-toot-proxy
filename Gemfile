source 'https://rubygems.org'
ruby '>= 4.0.2', '< 5.0'
gem 'concurrent-ruby'
gem 'dry-validation'
gem 'faye-websocket', github: 'pooza/faye-websocket-ruby'
gem 'ginseng-core', github: 'pooza/ginseng-core', branch: 'main', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', branch: 'main', require: 'ginseng/fediverse'
gem 'ginseng-piefed', github: 'pooza/ginseng-piefed', branch: 'main', require: 'ginseng/piefed'
gem 'ginseng-postgres', github: 'pooza/ginseng-postgres', branch: 'main'
gem 'ginseng-redis', github: 'pooza/ginseng-redis', branch: 'main', require: 'ginseng/redis'
gem 'ginseng-web', github: 'pooza/ginseng-web', branch: 'main', require: 'ginseng/web'
gem 'ginseng-youtube', github: 'pooza/ginseng-youtube', branch: 'main', require: 'ginseng/you_tube'
gem 'icalendar'
# JSON::Validator を app/lib/mulukhiya.rb で直に使う。ginseng-core の推移依存で
# 入ってはいるが、Bundler.require が読むのは Gemfile に書いた gem だけで、
# ginseng-core 側は Ginseng::Config が autoload された副作用で require していた。
# その副作用に頼ると、Config を触らない起動経路で NameError になる (#4509)。
gem 'json-schema'
gem 'marcel'
gem 'optparse'
gem 'parallel', '~> 2.0'
gem 'puma', '~> 8.0'
gem 'rspotify', github: 'pooza/rspotify', branch: 'master.pooza'
gem 'ruby-progressbar'
gem 'ruby-vips', require: 'vips'
gem 'sentry-ruby'
gem 'sentry-sidekiq'
gem 'sidekiq', '~>8.1'
gem 'sidekiq-scheduler', '~>6.0.1'
group :development do
  gem 'bundler-audit'
  # RuboCop 設定の正本。本体と minitest/performance/rake プラグインもこの gem が抱える。
  gem 'ginseng-style', github: 'pooza/ginseng-style', tag: 'v1.1.4', require: false
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
