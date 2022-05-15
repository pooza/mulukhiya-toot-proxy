module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disableable?
      return false
    end

    def exec
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      sns.account.user_config.update(parser.params)
      sns.account.user_config.token = sns.token
    end
  end
end
