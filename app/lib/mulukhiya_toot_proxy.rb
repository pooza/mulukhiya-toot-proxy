require 'bootsnap'
require 'active_support'
require 'active_support/core_ext'
require 'zeitwerk'
require 'sidekiq'
require 'sidekiq-scheduler'
require 'ginseng'
require 'ginseng/postgres'
require 'ginseng/web'

module MulukhiyaTootProxy
  def self.dir
    return File.expand_path('../..', __dir__)
  end

  def self.bootsnap
    Bootsnap.setup(
      cache_dir: File.join(dir, 'tmp/cache'),
      load_path_cache: true,
      autoload_paths_cache: true,
      compile_cache_iseq: true,
      compile_cache_yaml: true,
    )
  end

  def self.loader
    loader = Zeitwerk::Loader.new
    loader.enable_reloading
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.setup
    loader.inflector.inflect(Config.instance['/autoload/inflections'].first)
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.push_dir(File.join(dir, 'app/contract'))
    loader.push_dir(File.join(dir, 'app/daemon'))
    loader.push_dir(File.join(dir, 'app/dsn'))
    loader.push_dir(File.join(dir, 'app/file'))
    loader.push_dir(File.join(dir, 'app/handler'))
    loader.push_dir(File.join(dir, 'app/renderer'))
    loader.push_dir(File.join(dir, 'app/service'))
    loader.push_dir(File.join(dir, 'app/tagging_resource'))
    loader.push_dir(File.join(dir, 'app/uri'))
    loader.push_dir(File.join(dir, 'app/worker'))
    loader.reload
  end

  def self.sidekiq
    Sidekiq.configure_client do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
    end
    Sidekiq.configure_server do |config|
      config.redis = {url: Config.instance['/sidekiq/redis/dsn']}
    end
  end
end

MulukhiyaTootProxy.bootsnap
MulukhiyaTootProxy.loader
MulukhiyaTootProxy.sidekiq
