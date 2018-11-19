require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'

module MulukhiyaTootProxy
  extend ActiveSupport::Autoload

  autoload :AmazonService
  autoload :ArtistParser
  autoload :CommandHandler
  autoload :Config
  autoload :Environment
  autoload :Error
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
  autoload :Slack
  autoload :SpotifyService
  autoload :URLHandler, 'mulukhiya_toot_proxy/url_handler'

  autoload_under 'error' do
    autoload :ConfigError
    autoload :DatabaseError
    autoload :ExternalServiceError
    autoload :ImprementError
    autoload :NotFoundError
    autoload :RedisError
    autoload :RequestError
  end

  autoload :JSONRenderer, 'mulukhiya_toot_proxy/renderer/json_renderer'

  autoload :RedisDSN, 'mulukhiya_toot_proxy/dsn/redis_dsn'
  autoload :PostgresDSN, 'mulukhiya_toot_proxy/dsn/postgres_dsn'

  autoload :AmazonURI, 'mulukhiya_toot_proxy/uri/amazon_uri'
  autoload :ItunesURI, 'mulukhiya_toot_proxy/uri/itunes_uri'
  autoload :SpotifyURI, 'mulukhiya_toot_proxy/uri/spotify_uri'
end
