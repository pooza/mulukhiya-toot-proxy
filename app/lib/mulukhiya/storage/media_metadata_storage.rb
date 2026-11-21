module Mulukhiya
  class MediaMetadataStorage < JSONStorage
    attr_reader :http

    def initialize(params = {})
      super
      @http = HTTP.new
      @http.retry_limit = 1
    end

    # ⚠⚠ **`host_validator` は外部が決めた URL を取るときに渡す**（フィードの enclosure・#4749）。
    # 渡すと内部アドレスを取りに行かない（SSRF）。🔴 ginseng-web 3.0.3 は `fetch_image` の既定で
    # これを塞いだが、**モロヘイヤは `fetch_image` を上書きしてここへ委譲している**ので、
    # gem の修正は届かない。
    # ⚠ 添付（自分の SNS のメディア・`AttachmentMethods#meta`）には渡さない。ステージングのように
    # 自前のホストが内部アドレスに解決される環境で、メタデータが取れなくなる。
    # ⚠ 拒否も下の rescue でネガティブキャッシュに入る（5 分おきに引き直してログを積まない・#4549）。
    def push(uri, host_validator: nil)
      path = File.join(Environment.dir, 'tmp/media', uri.to_s.sha256)
      reading = false
      unless File.exist?(path)
        # ⚠ **URI にしてから渡す。**`RemoteHost.validate!` は `host` を持たない値を
        # ホスト名そのものとして扱うので、フィードから来る String の URL をそのまま渡すと
        # URL 全体を DNS に引いて必ず拒否する（公開ホストの enclosure が全滅する）。
        RemoteHost.validate!(Ginseng::URI.parse(uri.to_s)) if host_validator
        # ⚠ **宛先へ直接書かない (#4920)。**puma とワーカーが同じ媒体を同時に取りに行くと、
        # 書きかけのファイルを読んで空のメタデータを置いていた。形は `MediaFile.write_atomic` (#4626)。
        MediaFile.write_atomic(path, http.get(uri, {host_validator:}.compact).body.to_s)
      end
      reading = true
      values = MediaFile.new(path).file.values.merge(url: uri.to_s)
      reading = false
      set(uri, values)
      log(url: uri.to_s)
    # ⚠ ネガティブキャッシュを GatewayError だけに絞らない (#4549)。
    #
    # 呼び出し元（フィード生成）は 5 分おきに全エントリを舐め直すので、ここで
    # 空を置かない失敗は **毎サイクル同じ URL を叩き直し、同じログを出し続ける**。
    # 実際 URL が絶対化できない RuntimeError がこの rescue を通らず、
    # 1 サイクル 79 行 = 日 2 万行のログになっていた。
    #
    # ⚠⚠ **ただし空は短く置く (#4920)。**以前は成功と同じ ttl（既定 100 日）で、一時的な取得の失敗でも
    # その媒体は 100 日メタデータが空のままだった。1 日なら、5 分おきに舐め直すフィードでも
    # 1 つの URL のログは 1 日 1 行で済む。
    # ⚠ 読めなかったファイルは消す。残すと、次に引き直しても同じ壊れたファイルを読む。
    # ⚠⚠ **消すのは、ファイルがあって読めなかったときだけ（5.48.0 のリリース前レビュー）。**取得が落ちた側が
    # 消すと、同じ媒体を同時に取りに行った別のスレッドが書き終えたファイルを消す。読めたあとの失敗
    # （Redis への書き込み）でも消さない。
    rescue => e
      e.log(url: uri.to_s)
      FileUtils.rm_f(path) if reading
      set(uri, {}, ttl: negative_ttl)
    end

    NEGATIVE_TTL = 86_400

    # 取れなかったことを覚えておく秒数。⚠ 成功の ttl より長くはしない。
    def negative_ttl
      return [ttl, NEGATIVE_TTL].compact.min
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def symbolize_names?
      return true
    end

    def prefix
      return 'media_metadata'
    end
  end
end
