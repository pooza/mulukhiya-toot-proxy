module Mulukhiya
  class WelcomeMentionHandler < MentionHandler
    def disable?
      return true unless info_agent_service
      return false if event == :user_approved
      return super
    end

    def handle_follow(payload, params = {})
      self.payload = payload
      return unless sns = params[:sns]
      return if sender.bot?
      sns.notify(sender, create_body(params))
      result.push(sender: sender.acct.to_s)
    end

    def handle_user_approved(payload, params = {})
      return unless sns = params[:sns]
      return unless account = resolve_account(payload)
      return if account.bot?
      sns.notify(account, create_body(params))
      result.push(account: account.acct.to_s)
    end

    private

    def resolve_account(payload)
      account_id = payload.dig('object', 'id') || payload.dig('body', 'user', 'id') || payload.dig('body', 'id')
      return nil unless account_id
      return account_class[account_id]
    rescue => e
      e.log
      return nil
    end
  end
end
