module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Postgres.config?
      return false
    end

    def dispatch
      raise Ginseng::GatewayError, 'Invalid access token' unless id = sns.account.id
      @storage.update(id, parser.params)
      Environment.info_agent&.notify(sns.account, YAML.dump(message))
    end

    def message
      v = JSON.parse(@storage.get(sns.account.id))
      v['webhook']['url'] = sns.account.webhook.uri.to_s if v.dig('webhook', 'token')
      return v
    end

    def notifiable?
      return false
    end

    private

    def initialize(params = {})
      super(params)
      @storage = UserConfigStorage.new
    end
  end
end
