module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Postgres.config?
      return false
    end

    def dispatch
      raise Ginseng::GatewayError, 'Invalid access token' unless sns.account
      sns.account.config.update(parser.params)
      notify(message) unless Environment.test?
    end

    def message
      return sns.account.config.to_h
    end

    def notifiable?
      return false
    end
  end
end
