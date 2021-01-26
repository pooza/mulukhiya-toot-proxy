module Mulukhiya
  class Program
    include Singleton
    include Package

    def update
      File.write(path, @http.get(config['/programs/url'])) rescue nil
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/programs.json')
    end

    def data
      return JSON.parse(File.read(path))
    end

    def count
      return data.count
    end

    def to_yaml
      return data.to_yaml
    end

    alias to_s to_yaml

    private

    def initialize
      @http = HTTP.new
    end
  end
end
