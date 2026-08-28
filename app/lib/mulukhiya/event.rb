module Mulukhiya
  class Event
    include Package

    attr_reader :label, :params

    def initialize(label, params = {})
      raise "Invalid event '#{label}'" unless Event.syms.member?(label)
      params[:event] = label
      params[:reporter] ||= Reporter.new
      @label = label.to_sym
      @params = params
    end

    def name
      return label.to_s
    end

    def handlers(&block)
      return enum_for(__method__) unless block
      handler_names.filter_map {|v| Handler.create(v, params)}.each(&block)
    end

    def handler_names(&block)
      return enum_for(__method__) unless block
      resolve_pipeline
        .reject {|name| config.disable?(Handler.create(name))}
        .each(&block)
    end

    def all_handlers(&block)
      return enum_for(__method__) unless block
      all_handler_names.filter_map {|v| Handler.create(v, params)}.each(&block)
    end

    def all_handler_names(&block)
      return enum_for(__method__) unless block
      resolve_pipeline
        .sort_by(&:underscore)
        .each(&block)
    end

    def count
      return handler_names.count
    end

    def reporter
      return params[:reporter]
    end

    def method
      return :"handle_#{label}"
    end

    def dispatch(payload)
      profile = HandlerProfile.create(self)
      handlers do |handler|
        next if handler.disable?
        counter = profile&.create_counter
        started = HandlerProfile.clock if profile
        run_handler(handler, payload, counter)
        break if handler.break?
      rescue => e
        handler.errors.push(class: e.class.to_s, message: e.message)
      ensure
        # 例外で終わったハンドラも記録する。Thread#join は例外を再送出するため、
        # ここに置かないと「遅いうえに失敗するハンドラ」がプロファイルから消える。
        profile&.record(handler, started, counter) if started
        reporter.push(handler)
      end
      profile&.flush(payload)
      return reporter
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      syms.map {|v| new(v)}.each(&block)
    end

    def self.syms
      base_events = config.keys('/handler/pipeline/base') rescue []
      sns_events = config.keys("/handler/pipeline/#{Environment.controller_name}") rescue []
      return (base_events + sns_events).to_set(&:to_sym)
    end

    private

    # counter を渡すとハンドラのスレッドで HTTP が集計される (#4464)。
    # nil のときは計装なし＝従来どおりの挙動。
    def run_handler(handler, payload, counter)
      thread = Thread.new do
        Thread.current[HandlerProfile::HTTP_KEY] = counter
        handler.send(method, payload, params)
      end
      return if thread.join(handler.timeout)
      # ⚠⚠ **タイムアウトしたスレッドは止める (#4657)。**従来は `errors` へ積むだけで
      # **ワーカーは走り続けていた**。`webhook_image` の timeout は 10 秒だが、
      # 超えたハンドラが `Webhook#post` の `sns.post` より後に `push` すると
      # **上限は守れているのに投稿に載らない添付**が出る。
      #
      # ⚠ 放置とどちらが安全かではない。**放置は「もう送った payload へ後から書く」**
      # なので、途中で止めるほうが状態の壊れ方は小さい。
      thread.kill
      handler.errors.push(message: 'timeout', timeout: "#{handler.timeout}s")
    end

    def resolve_pipeline
      base = config["/handler/pipeline/base/#{label}"] rescue nil
      sns_config = config["/handler/pipeline/#{Environment.controller_name}/#{label}"] rescue nil
      return base if base.is_a?(Array) && sns_config.nil?
      return sns_config if sns_config.is_a?(Array)
      if base.is_a?(Array) && sns_config.is_a?(Hash)
        result = base.dup
        Array(sns_config['exclude']).each {|h| result.delete(h)}
        return result
      end
      return []
    end
  end
end
