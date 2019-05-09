module MulukhiyaTootProxy
  class AdminNotificationHandler < NotificationHandler
    def notifiable?(body)
      return false unless body['status'] =~ /#notify(\s|$)/i
      return false if body['visibility'] =~ /^(direct|private)$/
      return true if @mastodon.account['admin'] == 't'
      return true if @mastodon.account['moderator'] == 't'
      return false
    rescue => e
      @logger.error(e)
      return false
    end

    def handle_post_toot(body, params = {})
      return unless notifiable?(body)
      Slack.broadcast('aaaaa')
    end

    private

    def events
      return [:pre_toot, :post_toot]
    end
  end
end
