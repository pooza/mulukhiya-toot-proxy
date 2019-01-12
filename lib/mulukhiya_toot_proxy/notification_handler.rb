module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def exec(body, headers = {})
      return unless executable?(body, headers)
      worker_name.constantize.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        status: body['status'],
      })
      increment!
    end

    def worker_name
      return self.class.to_s.sub(/Handler$/, 'Worker')
    end

    def executable?(body, headers)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
