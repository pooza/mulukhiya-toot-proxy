module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Postgres.config?
      return false
    end

    def command_params
      params = parser.params.clone
      params['tags'] ||= []
      params['growi'] ||= {}
      params['dropbox'] ||= {}
      params['notify'] ||= {}
      params['amazon'] ||= {}
      return params
    end

    def exec
      raise Ginseng::AuthError, 'Invalid token' unless sns.account
      sns.account.config.update(parser.params)
    end
  end
end
