module Mulukhiya
  class WelcomeMessageFollowHandler < Handler
    def disable?
      return true unless Environment.dbms_class.config?
      return true unless controller_class.streaming?
      return true if config.disable?(self)
      return false
    end

    def handle_follow(payload, params = {})
      return unless sns = params[:sns]
      return unless id = payload.dig('account', 'id') || payload.dig('body', 'id')
      return unless account = account_class[id]
      return if account.bot?
      sns.notify(account, template.to_s)
    end

    def template
      return Template.new(config['/agent/info/follow/template'])
    end
  end
end
