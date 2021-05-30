source 'https://rubygems.org'
ruby '~>3.0.0'
gem 'bootsnap', '>=1.7.0'
gem 'dropbox_api'
gem 'dry-validation'
gem 'fastimage'
gem 'faye-websocket'
gem 'fileutils'
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', require: 'ginseng/fediverse'
gem 'ginseng-redis', github: 'pooza/ginseng-redis', require: 'ginseng/redis'
gem 'ginseng-web', github: 'pooza/ginseng-web', require: 'ginseng/web'
gem 'ginseng-youtube', github: 'pooza/ginseng-youtube', require: 'ginseng/you_tube'
gem 'mimemagic', '>=0.4.0'
gem 'mini_magick'
#gem 'mini_portile2', '<2.5.2' # todo: バージョン指定削除
gem 'rspotify'
gem 'ruby-progressbar'
gem 'sidekiq', '~>6.2.0'
gem 'sidekiq-failures'
gem 'sidekiq-scheduler', github: 'pooza/sidekiq-scheduler', branch: 'master.pooza'
gem 'sidekiq-unique-jobs'
gem 'vacuum', '~>3.0'

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
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
  gem 'slim_lint'
  gem 'test-unit'
  gem 'timecop'
end
