module Mulukhiya
  class WelcomeMentionHandler < MentionHandler
    def handle_follow(payload, params = {})
      self.payload = payload
      return unless sns = params[:sns]
      return if sender.bot?
      sns.notify(sender, create_body(params))
      result.push(sender: sender.acct.to_s)
    end
  end
end
