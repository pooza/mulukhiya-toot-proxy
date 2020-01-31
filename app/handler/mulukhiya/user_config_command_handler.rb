module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Postgres.config?
      return false
    end

    def dispatch
      raise Ginseng::GatewayError, 'Invalid access token' unless id = sns.account.id
      UserConfigStorage.new.update(id, parser.params)
    end

    def status
      v = JSON.parse(UserConfigStorage.new.get(sns.account.id)).deep_merge(parser.params)
      v.delete('command')
      if sns.account.webhook
        v['webhook'] ||= {}
        v['webhook']['url'] = sns.account.webhook.uri.to_s
      end
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message, e.backtrace
    end
  end
end
