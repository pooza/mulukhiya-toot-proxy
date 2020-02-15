module Mulukhiya
  class UserConfig
    include Package

    def initialize(account)
      @account = account if account.is_a?(Environment.account_class)
      if account.is_a?(Hash) && (token = account['/webhook/token'])
        @account ||= Environment.account_class.get(token: token)
      end
      @account ||= Environment.account_class[account]
      @storage = UserConfigStorage.new
      @values = @storage[@account.id]
    end

    def raw
      return JSON.parse(@storage.get(@account.id))
    end

    def [](key)
      return @values[key]
    end

    def update(values)
      @storage.update(@account.id, values)
      @values = @storage[@account.id]
    end

    def webhook_token
      return self['/webhook/token']
    end

    def webhook_token=(token)
      update(webhook: {token: token})
    end

    def to_h
      unless @hash
        @hash = raw.clone
        @hash['webhook']['url'] = @account.webhook.uri.to_s if raw.dig('webhook', 'token')
      end
      return @hash
    end

    def disable?(handler_name)
      return self["/handler/#{handler_name}/disable"]
    end
  end
end
