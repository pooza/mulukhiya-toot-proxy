module Mulukhiya
  class MediaMetadataStorage < Redis
    def get(path)
      return nil unless entry = super(path)
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def push(path)
      path = path.path if path.is_a?(File)
      setex(path, ttl, MediaFile.new(path).file.values.to_json)
    end

    def create_key(key)
      return super(File.read(key).adler32)
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
