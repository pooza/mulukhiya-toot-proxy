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
      end
      update(sort_by{|k, v| k.length}..to_h)
    end

    def exist?
      return File.exist?(TaggingDictionary.path)
    end

    def load
      update(Marshal.load(File.read(TaggingDictionary.path))) if exist?
    end

    def refresh
      File.write(TaggingDictionary.path, Marshal.dump(fetch))
      load
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h)
    end

    alias create refresh

    def delete
      File.unlink(TaggingDictionary.path) if exist?
    end

    def fetch
      result = {}
      TaggingResource.all do |resource|
        resource.parse.each do |k, v|
          result[k] ||= v
          result[k][:words] ||= []
          result[k][:words].concat(v[:words])
        end
      end
      return result.sort_by{|k, v| k.length}.to_h
    end

    def self.path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end
  end
end
