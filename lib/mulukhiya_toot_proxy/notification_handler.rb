module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def exec(body, headers = {})
      return unless notifiable?(body, headers)
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

    def notifiable?(body, headers)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias executable? notifiable?
  end
end
