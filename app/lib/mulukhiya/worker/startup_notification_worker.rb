module Mulukhiya
  class StartupNotificationWorker < Worker
    sidekiq_options retry: false

    FAIL_THRESHOLD = 2

    def disable?
      return true unless info_agent_service
      return super
    end

    def perform(params = {})
      health = Environment.health
      observed = extract_status(health)
      if notified?
        reported = previous_status || {}
        new_reported = apply_hysteresis(observed, reported)
        return if reported == new_reported
        send_notification(health, create_change_message(new_reported, reported))
        save_status(new_reported)
      else
        send_notification(health, create_startup_message(health))
        observed.each_key {|key| reset_ng_count(key)}
        save_status(observed)
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

    def apply_hysteresis(observed, reported)
      return observed.to_h do |key, status|
        if status == 'NG'
          count = bump_ng_count(key)
          [key, count >= FAIL_THRESHOLD ? 'NG' : (reported[key] || 'OK')]
        else
          reset_ng_count(key)
          [key, status]
        end
      end
    end

    def bump_ng_count(key)
      return redis.incr(ng_count_key(key)).to_i
    end

    def reset_ng_count(key)
      redis.del(ng_count_key(key))
    end

    def ng_count_key(key)
      return "health_ng_count:#{key}"
    end

    def send_notification(health, message)
      account_class.admins.each do |account|
        info_agent_service.notify(account, message)
      end
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

    def create_change_message(new_reported, reported)
      lines = ['ヘルスステータス変更']
      lines << ''
      new_reported.each do |key, status|
        prev = reported[key]
        if prev && prev != status
          lines << "#{key}: #{prev} → #{status}"
        else
          lines << "#{key}: #{status}"
        end
      end
      lines << ''
      lines << overall_status_line(new_reported)
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

    def overall_status_line(status_map)
      return 'ステータス: 異常 (503)' if status_map.values.any?('NG')
      return 'ステータス: 正常'
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
