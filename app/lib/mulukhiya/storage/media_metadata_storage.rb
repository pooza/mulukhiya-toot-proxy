module Mulukhiya
  class MediaMetadataStorage < Redis
    def [](key)
      return get(key)
    end

    def get(path)
      return nil unless entry = super(create_key(path))
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def push(path)
      path = path.path if path.is_a?(File)
      setex(create_key(path), ttl, MediaFile.new(path).file.values.to_json)
    end

    def create_key(key)
      key = Zlib.adler32(File.read(key))
      return super
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
