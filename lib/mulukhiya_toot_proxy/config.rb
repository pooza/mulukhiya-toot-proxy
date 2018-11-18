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
          ['application', 'local'].each do |basename|
            path = File.join(dir, "#{basename}#{suffix}")
            update(flatten('', YAML.load_file(path), '/')) if File.exist?(path)
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
      return ['.yml', '.yaml']
    end

    def [](key)
      value = super(key)
      return value if value.present?
      raise ConfigError, "'#{key}' が未設定です。"
    end

    private

    def flatten(prefix, node, glue)
      values = {}
      if node.instance_of?(Hash)
        node.each do |key, value|
          key = prefix + glue + key
          values.update(flatten(key, value, glue))
        end
      else
        values[prefix.downcase] = node
      end
      return values
    end
  end
end
