module MulukhiyaTootProxy
  class AdminNotificationHandler < SidekiqHandler
    def executable?(body, headers)
      return false unless body['status'] =~ /#notify(\s|$)/i
      return true if @mastodon.account['admin'] == 't'
      return true if @mastodon.account['moderator'] == 't'
      return false
    end

    def create_params(body, headers)
      return {
        id: @mastodon.account_id,
        token: @mastodon.token,
        status: body['status'],
      }
    end
  end
end
