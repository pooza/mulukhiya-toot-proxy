source 'https://rubygems.org'
ruby '>= 3.4.1', '< 5.0'
gem 'concurrent-ruby'
gem 'dry-validation'
gem 'faye-websocket', github: 'pooza/faye-websocket-ruby'
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', require: 'ginseng/fediverse'
gem 'ginseng-redis', github: 'pooza/ginseng-redis', require: 'ginseng/redis'
gem 'ginseng-web', github: 'pooza/ginseng-web', ref: '7c48f377b0d4e0644b45d1eda60fb970868bfb6a', require: 'ginseng/web' # 安定するまで
gem 'ginseng-youtube', github: 'pooza/ginseng-youtube', require: 'ginseng/you_tube'
gem 'marcel'
gem 'optparse'
gem 'parallel'
gem 'rack', '~> 3.1.0' # 安定するまで
gem 'rspotify'
gem 'ruby-progressbar'
gem 'ruby-vips', require: 'vips'
gem 'sidekiq', '~>8.0.5'
gem 'sinatra', '~> 4.1.0' # 安定するまで
gem 'sidekiq-scheduler', '~>6.0.1'
gem 'yamllint'

group :postgres do
  gem 'ginseng-postgres', github: 'pooza/ginseng-postgres'
end

group :mongo do
  gem 'mongo'
end

group :development do
  gem 'rack-test'
  gem 'rails-erb-lint'
  gem 'ricecream'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
  gem 'slim_lint'
  gem 'test-unit'
  gem 'timecop'
end
