module Mulukhiya
  class StartupNotificationWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless info_agent_service
      return super
    end

    def perform(params = {})
      health = Environment.health
      if notified?
        notify_if_changed(health)
      else
        notify_all(health, create_startup_message(health))
        redis['startup_notified_pid'] = sidekiq_pid
      end
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

    def notify_if_changed(health)
      previous = previous_status
      current = extract_status(health)
      return if previous == current
      notify_all(health, create_change_message(health, previous))
    end

    def notify_all(health, message)
      account_class.admins.each do |account|
        info_agent_service.notify(account, message)
      end
      save_status(extract_status(health))
      log(status: health[:status], admins: account_class.admins.count)
    end

    def extract_status(health)
      return health.except(:status).transform_values {|v| v[:status]}
    end

    def previous_status
      raw = redis['health_status']
      return nil unless raw
      return JSON.parse(raw).symbolize_keys
    rescue
      return nil
    end

    def save_status(status)
      redis['health_status'] = status.to_json
    end

    def create_startup_message(health)
      lines = ["モロヘイヤ v#{Package.version} 起動完了"]
      lines.concat(status_lines(health))
      return lines.join("\n")
    end

    def create_change_message(health, previous)
      lines = ['ヘルスステータス変更']
      lines << ''
      health.except(:status).each do |key, value|
        prev = previous&.dig(key)
        if prev && prev != value[:status]
          lines << "#{key}: #{prev} → #{value[:status]}"
        else
          lines << "#{key}: #{value[:status]}"
        end
      end
      lines << ''
      if health[:status] == 200
        lines << 'ステータス: 正常'
      else
        lines << "ステータス: 異常 (#{health[:status]})"
      end
      return lines.join("\n")
    end

    def status_lines(health)
      lines = ['']
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
      return lines
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
