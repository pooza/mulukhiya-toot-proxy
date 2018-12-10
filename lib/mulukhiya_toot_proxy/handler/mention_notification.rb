module MulukhiyaTootProxy
  class MentionNotificationHandler < SidekiqHandler
    def executable?(body, headers)
      return body['status'] =~ /(\s|^)@[[:word:]]+(\s|$)/i
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
