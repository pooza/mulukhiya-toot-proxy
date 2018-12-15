require 'yaml'
require 'singleton'

module MulukhiyaTootProxy
  class Config < Hash
    include Singleton

    def initialize
      super
      dirs.each do |dir|
        suffixes.each do |suffix|
          Dir.glob(File.join(dir, "*#{suffix}")).each do |f|
            update(flatten("/#{File.basename(f, suffix)}", YAML.load_file(f), '/'))
          end
          basenames.each do |basename|
            f = File.join(dir, "#{basename}#{suffix}")
            update(flatten('', YAML.load_file(f), '/')) if File.exist?(f)
          end
        end
      end
    end

    def dirs
      return [
        File.join('/etc', Package.name),
        File.join('/usr/local/etc', Package.name),
        File.join(ROOT_DIR, 'config'),
      ]
    end

    def suffixes
      return ['.yml', '.yaml']
    end

    def basenames
      return [
        'application',
        Environment.hostname,
        'local',
      ]
    end

    def [](key)
      value = super(key)
      return value if value.present?
      raise ConfigError, "'#{key}' not found"
    end

    private

    def flatten(prefix, node, glue)
      values = {}
      if node.is_a?(Hash)
        node.each do |key, value|
          values.update(flatten("#{prefix}#{glue}#{key}", value, glue))
        end
      else
        values[prefix.downcase] = node
      end
      return values
    end
  end
end
