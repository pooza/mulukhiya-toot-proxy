require 'bundler/setup'
require 'mulukhiya/refines'

module Mulukhiya
  using Refines

  def self.dir
    return File.expand_path('../..', __dir__)
  end

  def self.setup_bootsnap
    Bootsnap.setup(
      cache_dir: File.join(dir, 'tmp/cache'),
      development_mode: Environment.development?,
      load_path_cache: true,
      autoload_paths_cache: true,
      compile_cache_iseq: true,
      compile_cache_yaml: true,
    )
  end

  def self.loader
    config = YAML.load_file(File.join(dir, 'config/autoload.yaml'))
    loader = Zeitwerk::Loader.new
    loader.inflector.inflect(config['inflections'])
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.collapse('app/lib/mulukhiya/*')
    return loader
  end

  def self.setup_sidekiq
    Sidekiq.configure_client do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
    end
    Sidekiq.configure_server do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
      config.log_formatter = Sidekiq::Logger::Formatters::JSON.new
    end
    Redis.exists_returns_integer = true
  end

  def self.rack
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    if SidekiqDaemon.basic_auth?
      Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
        SidekiqDaemon.auth(username, password)
      end
    end
    return Rack::URLMap.new(
      '/' => Environment.controller_class,
      '/mulukhiya' => UIController,
      '/mulukhiya/api' => APIController,
      '/mulukhiya/feed' => FeedController,
      '/mulukhiya/webhook' => WebhookController,
      '/mulukhiya/sidekiq' => Sidekiq::Web,
    )
  end

  def self.connect_dbms
    Environment.dbms_class.connect
  end

  def self.load_tasks
    Dir.glob(File.join(dir, 'app/task/*.rb')).each do |f|
      require f
    end
  end
end

Bundler.require
Mulukhiya.loader.setup
Mulukhiya.setup_bootsnap
Mulukhiya.setup_sidekiq
Mulukhiya.connect_dbms
