require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'
require 'ginseng'
require 'ginseng/postgres'
require 'sidekiq'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym 'ASIN'
end

module MulukhiyaTootProxy
  extend ActiveSupport::Autoload

  autoload :AmazonService
  autoload :ArtistParser
  autoload :ClippingCommandHandler
  autoload :ClippingWorker
  autoload :CommandHandler
  autoload :Config
  autoload :DropboxClipper
  autoload :Environment
  autoload :GrowiClipper
  autoload :Handler
  autoload :ImageHandler
  autoload :ItunesService
  autoload :Logger
  autoload :Mastodon
  autoload :NotificationHandler
  autoload :NotificationWorker
  autoload :NowplayingHandler
  autoload :Package
  autoload :Postgres
  autoload :Redis
  autoload :ReverseMarkdown
  autoload :Server
  autoload :Slack
  autoload :SpotifyService
  autoload :Template
  autoload :TwitterService
  autoload :URLHandler
  autoload :UserConfigStorage

  autoload_under 'dsn' do
    autoload :RedisDSN
  end

  autoload_under 'uri' do
    autoload :AmazonURI
    autoload :ItunesURI
    autoload :MastodonURI
    autoload :SpotifyURI
    autoload :TwitterURI
  end

  autoload_under 'worker' do
    autoload :AdminNotificationWorker
    autoload :DropboxClippingWorker
    autoload :GrowiClippingWorker
    autoload :MentionNotificationWorker
  end
end

Sidekiq.configure_client do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end
