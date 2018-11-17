require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'

module MulukhiyaTootProxy
  extend ActiveSupport::Autoload

  autoload :AmazonService
  autoload :ArtistParser
  autoload :Config
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
  autoload :UrlHandler

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
    autoload :JsonRenderer
  end

  autoload_under 'uri' do
    autoload :AmazonUri
    autoload :ItunesUri
    autoload :SpotifyUri
  end
end
