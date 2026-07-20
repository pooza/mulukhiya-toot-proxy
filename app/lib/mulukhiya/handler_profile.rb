module Mulukhiya
  # ハンドラ実行の壁時計時間と外部 HTTP を計装する (#4464)。
  #
  # 「ニチアサ実況で投稿に数秒かかる」の内訳をハンドラ単位で説明可能にするのが目的。
  # 真犯人の候補は pre_toot の直列 HTTP（ShortenedURLHandler は 1 URL あたり最大 8 回の
  # リクエストを直列で投げる）であり、CPU ではなく I/O を疑っているため、
  # CPU 時間ではなく**壁時計時間**を採る。
  #
  # Event#dispatch がハンドラごとに Thread を立てるので、HTTP の集計は
  # スレッドローカルで自然にハンドラ単位へ分離される。
  class HandlerProfile
    include Package

    HTTP_KEY = :mulukhiya_handler_profile_http

    attr_reader :event, :entries

    def initialize(event)
      @event = event
      @entries = []
      @started = HandlerProfile.clock
    end

    # ハンドラのスレッドへ渡す集計先。nil を渡すと計測しない。
    def create_counter
      return Counter.new
    end

    def record(handler, started, counter)
      @entries.push({
        handler: handler.underscore,
        seconds: (HandlerProfile.clock - started).round(3),
        http_count: counter&.count || 0,
        http_seconds: (counter&.seconds || 0.0).round(3),
      })
    end

    def seconds
      return (HandlerProfile.clock - @started).round(3)
    end

    # 閾値を超えたイベントだけ 1 行で記録する。全件出すとニチアサの流量では
    # ログが読めなくなるため。
    def flush(payload)
      total = seconds
      return if total < HandlerProfile.threshold
      floor = HandlerProfile.floor
      logger.info({
        profile: event.name,
        seconds: total,
        payload: HandlerProfile.payload_shape(payload),
        handlers: entries.reject {|v| v[:seconds] < floor}.sort_by {|v| -v[:seconds]},
      })
    rescue => e
      e.log
    end

    class << self
      def create(event)
        return nil unless enable?
        return new(event)
      end

      def clock
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # ハンドラのスレッド内から呼ばれる。Ginseng::HTTP#log の prepend 経由。
      def record_http(seconds)
        Thread.current[HTTP_KEY]&.record(seconds)
      end

      # 「トゥートの種類別に内訳が見られること」(#4464) のための分類キー。
      # 本文そのものは出さない（個人情報をログに落とさない）。
      def payload_shape(payload)
        return {} unless payload.is_a?(Hash)
        text = [payload['status'], payload[:status], payload['text'],
          payload[:text]].compact.first.to_s
        return {
          chars: text.length,
          urls: text.scan(%r{https?://}).length,
          nowplaying: text.match?(/#nowplaying/i),
          attachments: Array(payload['media_ids'] || payload[:media_ids] ||
            payload['fileIds'] || payload[:fileIds]).length,
        }
      end

      def enable?
        return config['/profile/handler/enable'] == true
      rescue Ginseng::ConfigError => e
        # 計装が黙って無効化されるのを避ける（YJIT のサイレント欠落と同じ轍を踏まない）。
        warn_missing_config(e)
        return false
      end

      def threshold
        return config['/profile/handler/threshold'].to_f
      rescue Ginseng::ConfigError
        return DEFAULT_THRESHOLD
      end

      def floor
        return config['/profile/handler/floor'].to_f
      rescue Ginseng::ConfigError
        return DEFAULT_FLOOR
      end

      private

      def warn_missing_config(error)
        return if @warned
        @warned = true
        logger.error({
          message: 'handler profile config missing, profiling disabled',
          error: error.message,
        })
      end
    end

    DEFAULT_THRESHOLD = 1.0
    DEFAULT_FLOOR = 0.001

    # ハンドラ 1 つぶんの HTTP 集計。URLHandler や RemoteTagHandler は
    # Parallel の worker スレッドから並行に叩くため、排他が要る。
    class Counter
      attr_reader :count, :seconds

      def initialize
        @mutex = Thread::Mutex.new
        @count = 0
        @seconds = 0.0
      end

      def record(seconds)
        @mutex.synchronize do
          @count += 1
          @seconds += seconds.to_f
        end
      end
    end

    # Ruby のスレッドローカルは子スレッドへ継承されない。URLHandler#handle_pre_toot は
    # rewrite を Parallel.each(in_threads:) で回すため、これを補わないと
    # 「1 URL あたり最大 8 回の直列リクエスト」という最大の調査対象そのものが
    # http_count: 0 として記録されてしまう。
    module ParallelProbe
      [:each, :map, :each_with_index, :map_with_index, :flat_map].each do |name|
        define_method(name) do |*args, **opts, &block|
          counter = Thread.current[HandlerProfile::HTTP_KEY]
          next super(*args, **opts, &block) unless counter && block
          super(*args, **opts) do |*values|
            Thread.current[HandlerProfile::HTTP_KEY] = counter
            block.call(*values)
          end
        end
      end
    end

    # Ginseng::HTTP は全リクエストの所要時間を #log で算出しているため、
    # ここを唯一のフック点にできる。呼び出し側（handler / service）に手を入れずに
    # 「どのハンドラが何回 HTTP を打ったか」を採れる。
    #
    # 所要時間は Ginseng::HTTP#log が :start から算出するが、その代入は super の
    # 内側で起きるため、ここでは :start から自前で求める。
    #
    # 既知の欠落: リトライを使い切って失敗したリクエストは #log を通らないため
    # http_count に乗らない（そのぶんの待ち時間はハンドラの seconds には含まれる）。
    module HTTPProbe
      def log(message)
        if message.is_a?(Hash) && (start = message[:start] || message['start'])
          HandlerProfile.record_http(Time.now - start)
        end
        return super
      end
    end
  end
end
