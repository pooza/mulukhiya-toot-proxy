module Mulukhiya
  class MentionHandler < Handler
    attr_reader :sender

    def disable?
      return true unless Environment.dbms_class.config?
      return true unless controller_class.streaming?
      return false
    end

    def handle_follow(payload, params = {})
      return unless sns = params[:sns]
      return unless id = payload.dig('account', 'id') || payload.dig('body', 'id')
      return unless account = account_class[id]
      return if account.bot?
      sns.notify(account, template.to_s)
    end

    def handle_mention(payload, params = {})
      self.payload = payload
      return unless respondable?
      return unless sns = params[:sns]
      return if sender.bot?
      sns.notify(sender, create_body(params), payload['status'])
      @prepared = true
    end

    def payload=(payload)
      @payload = payload
      @status = payload.dig('status', 'content')
      id = payload.dig('account', 'id') || payload.dig('body', 'id')
      @sender = account_class[id]
    end

    def respondable?
      return true
    end

    def create_body(params = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
