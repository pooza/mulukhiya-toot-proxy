module Mulukhiya
  class MediaConvertHandler < Handler
    ALERT_THROTTLE_SECONDS = ControllerErrorMethods::ALERT_THROTTLE_SECONDS

    attr_reader :image_field, :file

    def handle_pre_upload(payload, params = {})
      @file = media_class.new(payload.dig(image_field, :tempfile).path)
      return unless convertable?
      return unless @dest = convert
      payload[image_field][:org_tempfile] ||= payload.dig(image_field, :tempfile)
      payload[image_field][:tempfile] = @dest
      update_metadata(payload)
    rescue => e
      # ⚠ **記録を先に積む。**`e.alert` は slack / line / mail を同期で回すので、
      # 通知先が遅いと外側の締切（`Event#run_handler` の join）に kill され、
      # 後ろに置いた `errors.push` へ届かない（#4722）。
      errors.push(class: e.class.to_s, message: e.message, file: file&.path)
      e.is_a?(Timeout::Error) ? alert_timeout(e) : e.alert
    end

    def handle_pre_thumbnail(payload, params = {})
      @image_field = :thumbnail
      handle_pre_upload(payload, params)
    end

    def handle_post_thumbnail(payload, params = {})
      @image_field = :thumbnail
      handle_post_upload(payload, params)
    end

    def convert
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def convertable?
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def type
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def media_class
      return ImageFile
    end

    private

    def initialize(params = {})
      super
      @image_field = :file
    end

    def update_metadata(payload)
      return unless type
      dest_file = media_class.new(@dest.path)
      payload[image_field][:type] = dest_file.type
      return unless payload[image_field][:filename]
      extname = dest_file.recommended_extname || File.extname(@dest.path)
      basename = File.basename(payload[image_field][:filename], '.*')
      payload[image_field][:filename] = "#{basename}#{extname}"
    end

    # 変換の締切切れ (#4722)。
    #
    # ⚠⚠ **締切切れは素の `e.alert` へ流さない。**ffmpeg の内側の締切（`ffmpeg_timeout`）が
    # 先に切れると `Timeout::Error` がここへ直行し、**長い動画 1 本ごとに Sentry と
    # slack / line / mail が鳴っていた。**ハンドラごとに窓のあいだ 1 回だけ鳴らし、
    # 残りは log に落とす（`ControllerErrorMethods#throttled_alert` と同じ考え方）。
    # ⚠ コマンドと締切は ginseng-core の `log_expired` が、段（remux / transcode）は
    # `VideoFile` が error の行に残している。
    def alert_timeout(error)
      values = {handler: underscore, file: file&.path}
      acquired = AlertThrottle.acquire(timeout_alert_key(error), ALERT_THROTTLE_SECONDS)
      return error.alert(values) if acquired
      return error.log(values.merge(throttled: true))
    end

    def timeout_alert_key(error)
      return [ControllerErrorMethods::ALERT_THROTTLE_KEY_PREFIX, error.class, self.class].join('/')
    end
  end
end
