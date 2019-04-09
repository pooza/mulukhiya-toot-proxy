module MulukhiyaTootProxy
  class TaggingDictionary < Hash
    def initialize
      super
      @logger = Logger.new
      @http = HTTP.new
      load
    end

    def concat(values)
      values.each do |k, v|
        self[k] ||= v
        self[k][:words] ||= []
        self[k][:words].concat(v[:words])
      rescue => e
        @logger.error(e)
        next
      end
      update(sort_by{|k, v| k.length}.to_h)
    end

    def exist?
      return File.exist?(path)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end

    def load
      update(Marshal.load(File.read(path))) if exist?
    end

    def refresh
      File.write(path, Marshal.dump(fetch))
      load
    rescue => e
      @logger.error(e)
    end

    alias create refresh

    def delete
      File.unlink(path) if exist?
    end

    def resources
      return enum_for(__method__) unless block_given?
      TaggingResource.all do |r|
        yield r
      end
    end

    def fetch
      result = {}
      resources do |resource|
        resource.parse.each do |k, v|
          result[k] ||= v
          result[k][:words] ||= []
          result[k][:words].concat(v[:words]) if v[:words]
        rescue => e
          @logger.error(e)
          next
        end
      rescue => e
        @logger.error(e)
        next
      end
      return result.sort_by{|k, v| k.length}.to_h
    end
  end
end
