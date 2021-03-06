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
    Redis.exists_returns_integer = true
    Sidekiq.configure_client do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
      config.client_middleware do |chain|
        chain.add SidekiqUniqueJobs::Middleware::Client
      end
    end
    Sidekiq.configure_server do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
      config.log_formatter = Sidekiq::Logger::Formatters::JSON.new
      config.client_middleware do |chain|
        chain.add SidekiqUniqueJobs::Middleware::Client
      end
      config.server_middleware do |chain|
        chain.add SidekiqUniqueJobs::Middleware::Server
      end
      SidekiqUniqueJobs::Server.configure(config)
    end
  end

  def self.setup_debug
    Ricecream.disable
    return unless Environment.development?
    Ricecream.enable
    Ricecream.include_context = true
    Ricecream.colorize = true
    Ricecream.prefix = "#{Package.name} | "
    Ricecream.define_singleton_method(:arg_to_s, proc {|v| PP.pp(v)})
  end

  def self.rack
    require 'sidekiq/web'
    require 'sidekiq-scheduler/web'
    if SidekiqDaemon.basic_auth?
      Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
        SidekiqDaemon.auth(username, password)
      end
    end
    Sidekiq::Web.use(Rack::Session::Cookie, {
      secret: Config.instance['/crypt/password'],
      same_site: true,
      max_age: Config.instance['/sidekiq/dashboard/session/max_age'],
    })
    return Rack::URLMap.new(
      '/' => Environment.controller_class,
      '/mulukhiya' => UIController,
      '/mulukhiya/api' => APIController,
      '/mulukhiya/feed' => FeedController,
      '/mulukhiya/webhook' => WebhookController,
      '/mulukhiya/sidekiq' => Sidekiq::Web,
    )
  end

  def self.load_tasks
    Dir.glob(File.join(dir, 'app/task/*.rb')).each do |f|
      require f
    end
  end

  Bundler.require
  loader.setup
  setup_bootsnap
  setup_sidekiq
  setup_debug
  Environment.dbms_class.connect
end
