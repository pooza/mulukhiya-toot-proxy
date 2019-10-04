require 'bootsnap'

Bootsnap.setup(
  cache_dir: File.join(File.expand_path('..', __dir__), 'tmp/cache'),
  load_path_cache: true,
  autoload_paths_cache: true,
  compile_cache_iseq: true,
  compile_cache_yaml: true,
)

require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies/autoload'
require 'ginseng'
require 'ginseng/postgres'
require 'ginseng/web'
require 'sidekiq'
require 'sidekiq-scheduler'
require 'yaml'

module MulukhiyaTootProxy
  extend ActiveSupport::Autoload

  autoload :Account
  autoload :ArtistParser
  autoload :ClippingWorker
  autoload :CommandHandler
  autoload :CommandLine
  autoload :Config
  autoload :DropboxClipper
  autoload :Environment
  autoload :GrowiClipper
  autoload :Handler
  autoload :HTTP
  autoload :ImageHandler
  autoload :Logger
  autoload :Mastodon
  autoload :MediaConvertHandler
  autoload :MediaFile
  autoload :NotificationHandler
  autoload :NotificationWorker
  autoload :NowplayingHandler
  autoload :Package
  autoload :Postgres
  autoload :QueryTemplate
  autoload :Redis
  autoload :ResultContainer
  autoload :Server
  autoload :Slack
  autoload :TagContainer
  autoload :TaggingDictionary
  autoload :TaggingResource
  autoload :Template
  autoload :Toot
  autoload :URLHandler
  autoload :UserConfigStorage
  autoload :Webhook

  autoload_under 'daemon' do
    autoload :SidekiqDaemon
    autoload :ThinDaemon
  end

  autoload_under 'contract' do
    autoload :AppAuthContract
    autoload :WebhookContract
  end

  autoload_under 'dsn' do
    autoload :RedisDSN
  end

  autoload_under 'file' do
    autoload :AudioFile
    autoload :ImageFile
    autoload :VideoFile
  end

  autoload_under 'renderer' do
    autoload :CSSRenderer
    autoload :HTMLRenderer
  end

  autoload_under 'service' do
    autoload :AmazonService
    autoload :ItunesService
    autoload :SpotifyService
    autoload :YouTubeService
  end

  autoload_under 'uri' do
    autoload :AmazonURI
    autoload :ItunesURI
    autoload :MastodonURI
    autoload :SpotifyURI
    autoload :VideoURI
  end

  autoload_under 'worker' do
    autoload :AdminNotificationWorker
    autoload :BoostNotificationWorker
    autoload :DropboxClippingWorker
    autoload :FavNotificationWorker
    autoload :GrowiClippingWorker
    autoload :MediaCleaningWorker
    autoload :MentionNotificationWorker
    autoload :ResultNotificationWorker
    autoload :TaggingDictionaryWorker
  end
end

Sidekiq.configure_client do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end
Sidekiq.configure_server do |config|
  config.redis = {url: MulukhiyaTootProxy::Config.instance['/sidekiq/redis/dsn']}
end
