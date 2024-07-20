require 'bundler/setup'
require 'mulukhiya/refines'

module Mulukhiya
  using Refines

  def self.dir
    return File.expand_path('../..', __dir__)
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
    daemon = SidekiqDaemon.new
    daemon.save_config
    config = YAML.load_file(daemon.config_cache_path).deep_symbolize_keys
    Sidekiq.strict_args!(false)
    Sidekiq.configure_client do |sidekiq|
      sidekiq.redis = {url: config.dig(:redis, :dsn)}
      sidekiq.logger = Sidekiq::Logger.new($stdout)
      sidekiq.logger.level = config.dig(:logger, :level)
      sidekiq.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    end
  end

  def self.setup_debug
    Ricecream.disable
    return unless Environment.development?
    require 'pp'
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
      same_site: true,
      max_age: Config.instance['/sidekiq/dashboard/session/max_age'],
    })
    return Rack::URLMap.new(Environment.route)
  end

  def self.load_tasks
    finder = Ginseng::FileFinder.new
    finder.dir = File.join(dir, 'app/task')
    finder.patterns.push('*.rb')
    finder.patterns.push('*.rake')
    finder.exec.each {|f| require f}
  end

  Dir.chdir(dir)
  ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')
  Bundler.require
  loader.setup
  setup_sidekiq
  setup_debug
  ENV['RACK_ENV'] ||= Environment.type
  Environment.dbms_class&.connect
end
