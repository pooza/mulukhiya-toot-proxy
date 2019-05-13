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
      AdminNotificationWorker.perform_async({
        from_account_id: @mastodon.account_id,
        token: @mastodon.token,
        status: body['status'],
        status_id: params[:results].response['id'],
      })
      @result.push(true)
    end
  end
end
