source 'https://rubygems.org'
ruby '~>3.1.0'
gem 'bootsnap', '>=1.9.0'
gem 'dry-validation'
gem 'fastimage'
gem 'faye-websocket', github: 'pooza/faye-websocket-ruby'
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng'
gem 'ginseng-fediverse', github: 'pooza/ginseng-fediverse', require: 'ginseng/fediverse'
gem 'ginseng-redis', github: 'pooza/ginseng-redis', require: 'ginseng/redis'
gem 'ginseng-web', github: 'pooza/ginseng-web', require: 'ginseng/web'
gem 'ginseng-youtube', github: 'pooza/ginseng-youtube', require: 'ginseng/you_tube'
gem 'marcel'
gem 'mini_magick'
gem 'optparse'
gem 'rspotify'
gem 'ruby-progressbar'
gem 'sidekiq', '~>6.4.0' # CVE-2022-23837
gem 'sidekiq-scheduler', '~>3.1.0'
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
  gem 'rubocop-minitest'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
  gem 'slim_lint'
  gem 'test-unit'
  gem 'timecop'
end
