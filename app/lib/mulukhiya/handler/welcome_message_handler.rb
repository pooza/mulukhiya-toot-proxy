module Mulukhiya
  class WelcomeMessageHandler < MentionHandler
    def handle_follow(payload, params = {})
      self.payload = payload
      return unless sns = params[:sns]
      return if sender.bot?
      sns.notify(sender, create_body(params))
    end

    def create_body(params = {})
      return Template.new(config['/agent/info/follow/template']).to_s
    end
  end
end
