module Mulukhiya
  class StartupNotificationWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless info_agent_service
      return super
    end

    def perform(params = {})
      return if notified?
      health = Environment.health
      account_class.admins.each do |account|
        info_agent_service.notify(account, create_message(health))
      end
      redis['startup_notified_pid'] = sidekiq_pid
      log(status: health[:status], admins: account_class.admins.count)
    rescue => e
      e.log
    end

    private

    def notified?
      return redis['startup_notified_pid'] == sidekiq_pid
    end

    def sidekiq_pid
      return Process.pid.to_s
    end

    def create_message(health)
      lines = ["モロヘイヤ v#{Package.version} 起動完了"]
      lines << ''
      health.except(:status).each do |key, value|
        lines << "#{key}: #{value[:status]}"
      end
      lines << ''
      if health[:status] == 200
        lines << 'ステータス: 正常'
      else
        lines << "ステータス: 異常 (#{health[:status]})"
      end
      schema_errors = config.errors
      if schema_errors.present?
        lines << ''
        lines << 'スキーマエラー:'
        schema_errors.each {|e| lines << "- #{e}"}
      end
      return lines.join("\n")
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
