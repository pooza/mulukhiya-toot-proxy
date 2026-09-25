module Mulukhiya
  # リモートの添付を tmp/media へ落とす経路。MediaFile に `extend` して
  # `MediaFile.download` として使う。
  #
  # ⚠ 切り出したのは、SSRF ガード・サイズ上限・アトミックな書き込みという
  # 「取得の関心事」を、ローカルファイルの判定・変換から分けて読めるようにするため
  # (#4635 で MediaFile が行数の上限を越えた)。
  module MediaFileDownloadMethods
    # リモート取得の既定上限 (32MiB)。Mastodon の既定 (動画 40MB / 画像 16MB)
    # より小さめに置く。webhook から取り込む添付を想定した値で、足りなければ
    # /media/download/max_bytes で上げる。
    DEFAULT_DOWNLOAD_MAX_BYTES = 33_554_432

    # リモートの URL を tmp/media へ落とす。
    #
    # ⚠ **host_validator は必須キーワード (#4635)。**どの validator を使うか
    # (pinning の有無) は呼び出し元が決める。ここで既定にするとダウンロード全般へ
    # pinning が効き、複数 A レコードのフォールバックが使えない相手 (大手 CDN) で
    # 取得できなくなる (#4524 のトレードオフ)。
    # ⚠⚠ ただし**渡さないことは許さない。**以前は省略すると無検証の `{}` で撃って
    # いたので、渡し忘れた呼び出しが黙って内部アドレスまで取りに行けた。省略は
    # Ruby が、nil は下の raise が HTTP を撃つ前に弾く。
    #
    # ⚠ **サイズ上限を持つ。**以前は Content-Length も本文長も見ずに
    # `File.write(path, get(uri).body)` していたので、巨大な応答をそのまま
    # メモリとディスクへ通していた。判定は word_suggest / program と同じ二段
    # (HEAD の Content-Length → 受信後の実測) で、HEAD 非対応の相手でも
    # 最終防衛線が残る。
    #
    # ⚠⚠ **上限は「受信中」には効かない (#4612)。**受信後の実測に届く時点で
    # 本文はすべてメモリに載っているので、`Content-Length` を出さない相手
    # (chunked) や過少申告する相手には上限を無視して読まされる。⚠ **image_url は
    # webhook から第三者が指定できる**ので、ワーカーのメモリ枯渇に繋がりうる。
    # 受信中に打ち切るには `Ginseng::HTTP#get` 側の口が要る
    # (pooza/ginseng-core#526)。着地したら `max_bytes:` へ載せ替えること。
    def download(uri, host_validator:)
      raise ArgumentError, 'host_validator is required' unless host_validator
      path = File.join(
        Environment.dir,
        'tmp/media',
        "#{uri.to_s.sha256}#{File.extname(uri.path)}",
      )
      raise_too_large!(uri, :content_length) unless
        valid_content_length?(uri, request_options(host_validator))
      body = HTTP.new.get(uri, request_options(host_validator)).body.to_s
      raise_too_large!(uri, :body) if body.bytesize > download_max_bytes
      write_atomic(path, body)
      return new(path).file
    end

    # ⚠⚠ **URI を例外メッセージへ埋めない (#4630)。**`Ginseng::Logger#mask_url` は
    # `\A` アンカーで「値そのものが URL」のときしかマスクしないので、文中へ埋めると
    # webhook から第三者が渡した `image_url`（署名付き URL のことがある）が
    # 平文で syslog に残る。**URI はマスクの効くフィールドで別に残す。**
    # ⚠ 必ず raise するメソッドは `!` で示す規約 (#4657)。
    def raise_too_large!(uri, phase)
      Logger.new.error(error: 'too large content', phase:, url: uri.to_s)
      raise Ginseng::GatewayError, 'Too large content'
    end

    # ⚠ **宛先へ直接書かない (#4626)。**`path` は URL の sha256 由来の**固定名**なので、
    # 同じ URL を同時に取りに行くと `File.write` の O_TRUNC が**読み出し中のファイルを
    # 0 バイトへ切り詰める**。`WebhookImageHandler` は `Parallel.each(in_threads:)` で
    # 同一プロセスの複数スレッドから走り、`Handler#upload` 経由の ItunesImage /
    # SpotifyImage / YouTubeImage も実況中に同じサムネイル URL を同時に掴む。
    #
    # 上流への送信は gem の `Ginseng::HTTP#upload` が `File.open(file, 'rb')` で
    # **ストリームしながら読む**ので、その窓は画像サイズによっては秒オーダーになる。
    # 切り詰められると**壊れた本文をアップロードする**か、`MediaFile#type` が
    # 0 バイトを見て `file` が nil を返し、**添付が黙って消えた投稿**になる。
    #
    # ⚠ **rename はアトミック。**先に開いた読み手は古い inode を最後まで読み切り、
    # 後から開く者は完全な新ファイルを見るので、途中の状態は誰にも観測されない。
    # 形は `ProgramFetcher#write_yaml` と同じ。
    #
    # ⚠ **一時ファイル名をドット始まりにしない。**`MediaFile.all` の掃除は `*` glob
    # なので、ドット始まりだとクラッシュ時の残骸が永久に残る。
    def write_atomic(path, body)
      tmp = "#{path}.#{Process.pid}.#{Thread.current.object_id}"
      File.write(tmp, body)
      return File.rename(tmp, path)
    end

    # HTTP 呼び出しごとに**作り直す**オプション。
    #
    # ⚠⚠ **同じ hash を head と get で使い回してはいけない (pooza/ginseng-core#528)。**
    # `Ginseng::HTTP#request` は `options.delete(:host_validator)` で**呼び出し側の
    # hash を破壊する**ため、プリフライト（HEAD）を通した時点で validator が消え、
    # **本命の GET が無検証で撃たれる**（＝ HTTParty の自動追従に戻り、リダイレクト先が
    # 内部アドレスでも追従する）。実測でも validator の呼び出しは HEAD の 1 回だけだった。
    # ⚠ **「プリフライトを足したせいで GET の検証が外れる」**という、#4523 が塞ごうとした
    # ものの裏返し。gem 側の是正は pooza/ginseng-core#528 で、こちらは**それが入っても
    # 壊れない書き方**にしておく。
    def request_options(host_validator)
      return {host_validator:}
    end

    # 相手が申告した Content-Length が上限を超えていれば GET せずに弾く。
    # ⚠ Content-Length 不在・HEAD 非対応 (403 / 405) は「判定不能」として GET へ
    # 倒す。受信後の実測が最終防衛線 (#4576 / word_suggest と同じ形)。
    # ⚠ **プリフライトにも同じ host_validator を渡す。**ここだけ無検証だと
    # GET 側のガードが見せかけの安全になる (#4523)。
    def valid_content_length?(uri, options = {})
      length = HTTP.new.head(uri, options).headers['content-length']
      return true if length.nil? || length.to_i <= download_max_bytes
      Logger.new.error(
        message: 'media download content-length exceeded max bytes',
        url: uri.to_s,
        bytes: length.to_i,
        max_bytes: download_max_bytes,
      )
      return false
    rescue Ginseng::GatewayError => e
      # ⚠ allowlist 拒否 (Rejected host) はここで飲まない。飲むと「プリフライトが
      # true = GET してよい」が成り立たなくなる (#4535)。
      # ⚠ 文字列一致なのは、ginseng-core が拒否を専用の例外クラスでなく
      # GatewayError のメッセージで表しているため (#4635)。
      raise if e.message.start_with?('Rejected host')
      log_preflight_failure(e, uri)
      return true
    rescue => e
      log_preflight_failure(e, uri)
      return true
    end

    # HEAD 非対応 (403 / 405) は想定内なので黙って GET へ倒し、5xx・タイムアウト等の
    # 異常だけログする。以前はここだけ無音で、相手の障害が syslog に 1 行も
    # 残らなかった (#4635)。形は ProgramFetcher#valid_content_length? と同じ (#4397)。
    def log_preflight_failure(error, uri)
      status = error.respond_to?(:source_status) ? error.source_status : nil
      error.log(url: uri.to_s) unless [403, 405].include?(status)
    end

    def download_max_bytes
      return Config.instance['/media/download/max_bytes'] || DEFAULT_DOWNLOAD_MAX_BYTES
    rescue Ginseng::ConfigError
      return DEFAULT_DOWNLOAD_MAX_BYTES
    end
  end
end
