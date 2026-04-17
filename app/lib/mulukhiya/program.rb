module Mulukhiya
  class Program
    include Singleton
    include Package

    YAML_PATH = File.join(Environment.dir, 'var/program.yaml').freeze
    REDIS_KEY = 'program'.freeze

    def update
      return nil unless uris.any?
      return save(fetch_remote)
    end

    def save(programs)
      write_yaml(programs)
      return update_cache(programs)
    end

    def data
      return cached_data || load_from_yaml
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def count
      return data.count
    end

    def to_yaml
      return data.to_yaml
    end

    def uris
      return config['/program/urls'].filter_map {|v| Ginseng::URI.parse(v)}.to_set rescue []
    end

    def yaml_exist?
      return File.exist?(YAML_PATH)
    end

    def invalidate_cache
      redis.unlink(REDIS_KEY)
    end

    alias to_s to_yaml

    private

    def initialize
      @http = HTTP.new
    end

    def fetch_remote
      return uris.inject({}) do |programs, v|
        programs.merge(@http.get(v).parsed_response)
      end
    end

    def cached_data
      raw = redis[REDIS_KEY]
      return nil unless raw
      return JSON.parse(raw)
    end

    def load_from_yaml
      return {} unless yaml_exist?
      programs = YAML.safe_load_file(YAML_PATH, permitted_classes: [Symbol]) || {}
      update_cache(programs)
      return programs
    end

    def update_cache(programs)
      return redis[REDIS_KEY] = programs.to_json
    end

    def write_yaml(programs)
      dir = File.dirname(YAML_PATH)
      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, ".program.yaml.#{Process.pid}.#{Thread.current.object_id}")
      File.write(tmp, programs.to_yaml)
      File.rename(tmp, YAML_PATH)
    end
  end
end
