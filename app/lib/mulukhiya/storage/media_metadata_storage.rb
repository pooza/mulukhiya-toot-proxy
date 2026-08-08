module Mulukhiya
  class MediaMetadataStorage < Redis
    attr_reader :http

    def initialize(params = {})
      super
      @http = HTTP.new
      @http.retry_limit = 1
    end

    def get(uri)
      return supernil unless entry = super
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      e.log(key:)
      return nil
    end

    def set(uri, value)
      setex(uri, ttl, value.to_json)
    end

    def push(uri)
      path = File.join(Environment.dir, 'tmp/media', uri.to_s.sha256)
      File.write(path, http.get(uri)) unless File.exist?(path)
      values = MediaFile.new(path).file.values.merge(url: uri.to_s)
      set(uri, values)
      log(url: uri.to_s)
    # ⚠ ネガティブキャッシュを GatewayError だけに絞らない (#4549)。
    #
    # 呼び出し元（フィード生成）は 5 分おきに全エントリを舐め直すので、ここで
    # 空を置かない失敗は **毎サイクル同じ URL を叩き直し、同じログを出し続ける**。
    # 実際 URL が絶対化できない RuntimeError がこの rescue を通らず、
    # 1 サイクル 79 行 = 日 2 万行のログになっていた。
    # 一過性の障害も ttl のあいだ諦めることになるが、それは GatewayError で既にそう。
    rescue => e
      e.log(url: uri.to_s)
      set(uri, {})
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
