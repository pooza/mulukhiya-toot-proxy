module Mulukhiya
  class ScriptStorage < Redis
    def [](key)
      return get(key)
    end

    def get(key)
      unless super(create_key(key))
        setex(create_key(key), ttl, compress(key))
      end
      return super(create_key(key))
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def compressor
      @compressor ||= Uglifier.new(harmony: true)
      return @compressor
    end

    def compress(path)
      return compressor.compile(File.read(path))
    end

    def create_key(key)
      key = Zlib.adler32(File.read(key))
      return super
    end

    def ttl
      return config['/webui/cache/ttl']
    end

    def prefix
      return 'script'
    end
  end
end
