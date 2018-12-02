require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'
require 'sidekiq'
require 'sidekiq/web'

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
  autoload :Environment
  autoload :Error
  autoload :Growi
  autoload :Handler
  autoload :ImageHandler
  autoload :ItunesService
  autoload :Logger
  autoload :Mastodon
  autoload :NowplayingHandler
  autoload :Package
  autoload :Postgres
  autoload :Redis
  autoload :Renderer
  autoload :Server
  autoload :SidekiqHandler
  autoload :Slack
  autoload :SpotifyService
  autoload :TwitterService
  autoload :URLHandler
  autoload :UserConfigStorage

  autoload_under 'error' do
    autoload :ConfigError
    autoload :DatabaseError
    autoload :ExternalServiceError
    autoload :ImprementError
    autoload :NotFoundError
    autoload :RedisError
    autoload :RequestError
  end

  autoload_under 'renderer' do
    autoload :JSONRenderer
  end

  autoload_under 'dsn' do
    autoload :RedisDSN
    autoload :PostgresDSN
  end

  autoload_under 'uri' do
    autoload :AmazonURI
    autoload :ItunesURI
    autoload :MastodonURI
    autoload :SpotifyURI
    autoload :TwitterURI
  end
end

Sidekiq.configure_server do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end

Sidekiq.configure_client do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end
