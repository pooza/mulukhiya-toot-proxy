module Mulukhiya
  class NotificationHandler < Handler
    def disable?
      return !Environment.mastodon? || @config.disable?(underscore_name)
    rescue Ginseng::ConfigError
      return true
    end

    def notifiable?(body)
      return true
    end

    def worker_class
      return self.class.to_s.sub(/Handler$/, 'Worker').constantize
    end

    def handle_post_toot(body, params = {})
      @status = body[status_field].to_s
      return if parser.command?
      return unless notifiable?(body)
      worker_class.perform_async(account_id: sns.account.id, status: body[status_field])
      @result.push(true)
    end
  end
end
