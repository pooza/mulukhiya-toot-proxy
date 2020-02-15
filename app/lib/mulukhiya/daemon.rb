module Mulukhiya
  class Daemon < Ginseng::Daemon
    include Package

    def start(args)
      save_config
      super(args)
    end

    def name
      return self.class.to_s.split('::').last.sub(/Daemon$/, '').underscore
    end

    def save_config
      config = @config.raw['application'].dig(name)
      if values = @config.raw['local']&.dig(name)
        config.deep_merge!(values)
      end
      File.write(config_cache_path, config.to_yaml)
    end

    def config_cache_path
      return File.join(Environment.dir, "tmp/cache/#{name}.yaml")
    end

    def master_config_path
      return File.join(Environment.dir, 'config/application.yaml')
    end

    def local_config_path
      return File.join(Environment.dir, 'config/local.yaml')
    end
  end
end
