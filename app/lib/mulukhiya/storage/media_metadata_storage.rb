require 'digest/sha1'

module Mulukhiya
  class MediaMetadataStorage < Redis
    def [](file)
      return get(key)
    end

    def get(path)
      key = Digest::SHA1.hexdigest(File.read(path))
      return nil unless entry = super(create_key(key))
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      @logger.error(error: e, key: key)
      return nil
    end

    def push(path)
      path = path.path if path.is_a?(File)
      key = Digest::SHA1.hexdigest(File.read(path))
      setex(create_key(key), ttl, MediaFile.new(path).file.values.to_json)
    end

    def ttl
      return @config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
