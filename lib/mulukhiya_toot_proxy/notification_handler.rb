module MulukhiyaTootProxy
  class NotificationHandler < Handler
    def notifiable?(body)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    alias executable? notifiable?

    def events
      return [:post_toot, :post_webhook]
    end
  end
end
