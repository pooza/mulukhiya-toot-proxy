require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym 'JSON'
  inflect.acronym 'URL'
  inflect.acronym 'URI'
  inflect.acronym 'DSN'
  inflect.acronym 'ASIN'
end

module MulukhiyaTootProxy
  extend ActiveSupport::Autoload

  autoload :AmazonService
  autoload :ArtistParser
  autoload :CommandHandler
  autoload :Config
  autoload :DropboxClipper
  autoload :Environment
  autoload :Error
  autoload :GrowiClipper
  autoload :Handler
  autoload :ImageHandler
  autoload :ItunesService
  autoload :Logger
  autoload :Mastodon
  autoload :NowplayingHandler
  autoload :NotificationWorker
  autoload :Package
  autoload :Postgres
  autoload :Redis
  autoload :Renderer
  autoload :ReverseMarkdown
  autoload :Server
  autoload :SidekiqHandler
  autoload :Slack
  autoload :SpotifyService
  autoload :Template
  autoload :TwitterService
  autoload :URLHandler
  autoload :UserConfigStorage

  autoload_under 'dsn' do
    autoload :RedisDSN
    autoload :PostgresDSN
  end

  autoload_under 'error' do
    autoload :ConfigError
    autoload :DatabaseError
    autoload :ExternalServiceError
    autoload :ImplementError
    autoload :NotFoundError
    autoload :RedisError
    autoload :RequestError
  end

  autoload_under 'renderer' do
    autoload :JSONRenderer
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
