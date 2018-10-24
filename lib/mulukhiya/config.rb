require 'yaml'
require 'singleton'
require 'mulukhiya/package'
require 'mulukhiya/error/config'

module MulukhiyaTootProxy
  class Config < ::Hash
    include Singleton

    def initialize
      super
      dirs.each do |dir|
        suffixes.each do |suffix|
          Dir.glob(File.join(dir, "*#{suffix}")).each do |f|
            key = File.basename(f, suffix)
            self[key] = YAML.load_file(f) unless self[key]
          end
        end
      end
    end

    def dirs
      return [
        File.join('/usr/local/etc', Package.name),
        File.join('/etc', Package.name),
        File.join(ROOT_DIR, 'config'),
      ]
    end

    def suffixes
      return ['.yaml', '.yml']
    end

    def self.validate(name)
      keys = name.split('/')
      keys.shift
      config = instance
      keys.each do |key|
        config = config[key]
        raise ConfigError, "#{name} が未定義です。" unless config.present?
      end
    end
  end
end
