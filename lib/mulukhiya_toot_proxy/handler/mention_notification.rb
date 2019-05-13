module MulukhiyaTootProxy
  class MentionNotificationHandler < NotificationHandler
    def notifiable?(body)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/
    end

    def handle_post_toot(body, params = {})
      return unless notifiable?(body)
      MentionNotificationWorker.perform_async({
        id: @mastodon.account_id,
        token: @mastodon.token,
        status: body['status'],
      })
      @result.push(true)
    end
  end
end
