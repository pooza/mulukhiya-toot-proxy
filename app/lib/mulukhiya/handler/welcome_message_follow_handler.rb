module Mulukhiya
  class WelcomeMessageFollowHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return true unless Environment.controller_class.listener?
      return false
    end

    def handle_follow(payload, params = {})
      return payload unless sns = params[:sns]
      return payload unless account = Environment.account_class[payload.dig('account', 'id')]
      sns.notify(account, template.to_s)
      return payload
    end

    def template
      return Template.new(config['/agent/info/follow/template'])
    end
  end
end
