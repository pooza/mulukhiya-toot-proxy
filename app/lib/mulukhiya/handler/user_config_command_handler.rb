module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Postgres.config?
      return false
    end

    def validate
      parser.params['tags'] ||= []
      parser.params['growi'] ||= {}
      parser.params['dropbox'] ||= {}
      parser.params['notify'] ||= {}
      parser.params['amazon'] ||= {}
      return super
    end

    def exec
      raise Ginseng::AuthError, 'Invalid token' unless sns.account
      sns.account.config.update(parser.params)
    end
  end
end
