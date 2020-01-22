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
      values = YAML.load_file(master_config_path).dig(name)
      local_values = YAML.load_file(local_config_path).dig(name)
      values = Config.deep_merge(values, local_values) if local_values
      File.write(config_cache_path, YAML.dump(values))
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
