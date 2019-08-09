module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def disable?
      return @config.disable?(underscore_name)
    rescue Ginseng::ConfigError
      return false
    end

    def notifiable?(body)
      return true
    end

    def worker_class
      return self.class.to_s.sub(/Handler$/, 'Worker').constantize
    end

    def handle_post_toot(body, params = {})
      return unless notifiable?(body)
      worker_class.perform_async(account_id: mastodon.account.id, status: body['status'])
      @result.push(true)
    end
  end
end
