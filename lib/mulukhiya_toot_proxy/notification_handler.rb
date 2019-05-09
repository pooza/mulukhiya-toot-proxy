module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def hook_pre_toot(body, params = {})
      return unless notifiable?(body)
      worker_name.constantize.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        status: body['status'],
      })
      @result.push(true)
    end

    def worker_name
      return self.class.to_s.sub(/Handler$/, 'Worker')
    end

    def notifiable?(body)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias executable? notifiable?
  end
end
