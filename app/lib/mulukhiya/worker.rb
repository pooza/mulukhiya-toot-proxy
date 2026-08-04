module Mulukhiya
  class Worker
    include Sidekiq::Worker
    include Package
    include SNSMethods

    # 🔴 disable? を override した worker は、**perform 冒頭でも `return if disable?`
    # を書くこと** (#4343 / #4506)。
    #
    # 下の Worker.perform_async は disable? を見て enqueue を止めるが、
    # **sidekiq-scheduler は perform_async を介さず Sidekiq::Client.push を直叩きする**
    # ため、schedule 経由の起動はこの gate を一切通らない。schedule を持つ worker で
    # perform 側の短絡を欠くと、機能を無効にしたサーバーでも本体が 1〜10 分おきに走る。
    #
    # 基底側で perform を一律ラップする案もあるが、disable? の中身は worker ごとに
    # DB / 外部 API を叩くものがあり（例: FeedUpdateWorker の CustomFeed.all）、
    # 全 worker の毎回の起動でその評価コストを払うことになるので採らない。
    # 代わりに test/unit/worker/disable_gate.rb が「disable? を override している
    # 全 worker が perform で短絡すること」を機械的に検査する。
    def disable?
      return false
    end

    def underscore
      return self.class.to_s.split('::').last.sub(/Worker$/, '').underscore
    end

    def worker_config(*keys)
      path = keys.join('/')
      value = config["/worker/#{underscore}/#{path}"] rescue nil
      value = config["/worker/default/#{path}"] rescue nil if value.nil?
      return value
    end

    def initialize_params(params)
      return unless params.present?
      params.deep_symbolize_keys!
      log(params:)
    end

    def log(message)
      logger.info({worker: underscore, jid:}.merge(message))
    end

    def self.create(name)
      return "Mulukhiya::#{name.to_s.sub(/_worker$/, '').camelize}Worker".constantize.new
    rescue => e
      e.log(name:)
      return nil
    end

    def self.perform_async(*args)
      return if new.disable?
      if Environment.development? || Environment.test?
        args.push({}) unless args.present?
        args.each {|params| new.perform(params.deep_symbolize_keys)}
      else
        client_push('class' => self, 'args' => args.map(&:deep_symbolize_keys))
      end
    rescue => e
      e.alert
      raise e.message, e.backtrace
    end
  end
end
