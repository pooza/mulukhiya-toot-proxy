module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def exec
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      sns.account.user_config.update(parser.params)
      sns.account.user_config.token = sns.token
    end
  end
end
