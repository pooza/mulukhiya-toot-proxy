module Mulukhiya
  class MediaFile < File
    include Package

    # リモート取得の既定上限 (32MiB)。Mastodon の既定 (動画 40MB / 画像 16MB)
    # より小さめに置く。webhook から取り込む添付を想定した値で、足りなければ
    # /media/download/max_bytes で上げる。
    DEFAULT_DOWNLOAD_MAX_BYTES = 33_554_432

    def valid?
      return mediatype == default_mediatype
    end

    def mediatype
      return type.split('/').first
    end

    def default_mediatype
      return self.class.to_s.split('::').last.underscore.split('_').first
    end

    def subtype
      return type.split('/').last
    end

    def image?
      return mediatype == 'image'
    end

    def image_file
      return ImageFile.new(path)
    end

    def video?
      return mediatype == 'video'
    end

    def video_file
      return VideoFile.new(path)
    end

    def audio?
      return mediatype == 'audio'
    end

    def audio_file
      return AudioFile.new(path)
    end

    def file
      return image_file if image?
      return video_file if video?
      return audio_file if audio?
      return
    end

    def recommended_name
      @recommended_name ||= File.basename(path, File.extname(path)) + recommended_extname
      return @recommended_name
    end

    def type
      type = Marcel::MimeType.for Pathname.new(path)
      if type.split('/').first == 'application'
        command = CommandLine.new(['file', '-b', '--mime', path])
        command.exec
        type = command.stdout.split(';').first if command.status.zero?
      end
      return type
    rescue => e
      e.log(file: path)
      return MIMEType::DEFAULT
    end

    def extname
      return File.extname(path)
    end

    def recommended_extname
      return MIMEType.extname(type)
    end

    alias valid_extname recommended_extname

    def recommended_extname?
      return true if recommended_extname.nil?
      return extname == recommended_extname
    end

    alias valid_extname? recommended_extname?

    def width
      return nil
    end

    def height
      return nil
    end

    def duration
      return nil
    end

    def aspect
      return width.to_f / height rescue nil
    end

    def long_side
      return [width, height].max rescue nil
    end

    def convert_type(type)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias convert_format convert_type

    def create_dest_path(params = {})
      params[:extname] ||= MIMEType.extname(params[:type])
      params[:extname] ||= ".#{default_mediatype}"
      params[:content] = File.read(path).sha256
      return File.join(
        Environment.dir,
        'tmp/media',
        "#{params[:content]}#{params[:extname]}",
      )
    end

    def video_stream
      unless @video
        command = FFmpegCommandBuilder.probe_video(path)
        command.exec(timeout: probe_timeout)
        @video = JSON.parse(command.stdout)['streams'].first
      end
      return @video
    end

    def audio_stream
      unless @audio
        command = FFmpegCommandBuilder.probe_audio(path)
        command.exec(timeout: probe_timeout)
        @audio = JSON.parse(command.stdout)['streams'].first
      end
      return @audio
    end

    def container
      unless @container
        command = FFmpegCommandBuilder.probe_container(path)
        command.exec(timeout: probe_timeout)
        @container = JSON.parse(command.stdout)
      end
      return @container
    end

    def probe_timeout
      return Config.instance['/ffmpeg/probe/timeout']
    rescue
      return 30
    end

    # リモートの URL を tmp/media へ落とす。
    #
    # ⚠ **host_validator を渡すのは呼び出し元の責務 (#4576)。**ここで既定に
    # するとダウンロード全般へ pinning が効き、複数 A レコードのフォールバックが
    # 使えない相手 (大手 CDN) で取得できなくなる (#4524 のトレードオフ)。
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
    def self.download(uri, params = {})
      path = File.join(
        Environment.dir,
        'tmp/media',
        "#{uri.to_s.sha256}#{File.extname(uri.path)}",
      )
      options = {}
      options[:host_validator] = params[:host_validator] if params[:host_validator]
      raise Ginseng::GatewayError, "Too large content '#{uri}'" unless
        valid_content_length?(uri, options)
      body = HTTP.new.get(uri, options).body.to_s
      raise Ginseng::GatewayError, "Too large content '#{uri}'" if
        body.bytesize > download_max_bytes
      File.write(path, body)
      return new(path).file
    end

    # 相手が申告した Content-Length が上限を超えていれば GET せずに弾く。
    # ⚠ Content-Length 不在・HEAD 非対応 (403 / 405) は「判定不能」として GET へ
    # 倒す。受信後の実測が最終防衛線 (#4576 / word_suggest と同じ形)。
    # ⚠ **プリフライトにも同じ host_validator を渡す。**ここだけ無検証だと
    # GET 側のガードが見せかけの安全になる (#4523)。
    def self.valid_content_length?(uri, options = {})
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
      raise if e.message.start_with?('Rejected host')
      return true
    rescue
      return true
    end

    def self.download_max_bytes
      return Config.instance['/media/download/max_bytes'] || DEFAULT_DOWNLOAD_MAX_BYTES
    rescue Ginseng::ConfigError
      return DEFAULT_DOWNLOAD_MAX_BYTES
    end

    def self.purge
      worker = Worker.create(:media_cleaning)
      time = worker.worker_config(:hours).hours.ago
      deletable_files = all.select {|f| File.new(f).mtime < time}
      Parallel.each(deletable_files, in_threads: Parallel.processor_count * 2) do |path|
        FileUtils.rm_rf(path)
        logger.info(class: to_s, method: __method__, path:)
      rescue => e
        e.log(path:)
      end
      blank_dirs.each {|v| FileUtils.rm_rf(v)}
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'tmp/media')
      finder.patterns.push('*')
      finder.exec.select {|f| FileTest.file?(f)}.each(&block)
    end

    def self.blank_dirs(&block)
      return enum_for(__method__) unless block
      finder = Ginseng::FileFinder.new
      finder.dir = File.join(Environment.dir, 'tmp/media')
      finder.patterns.push('*')
      finder.exec
        .select {|path| FileTest.directory?(path)}
        .select {|path| Dir.new(path).entries.length == 2}
        .each(&block)
    end
  end
end
