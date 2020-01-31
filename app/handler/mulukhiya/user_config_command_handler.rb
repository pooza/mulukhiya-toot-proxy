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
      v = deep_merge(
        JSON.parse(UserConfigStorage.new.get(sns.account.id) || '{}'),
        parser.params,
      )
      v.delete('command')
      v['webhook']['url'] = sns.account.webhook&.uri.to_s if v.dig('webhook', 'token')
      return YAML.dump(v)
    rescue => e
      @logger.error(e)
      raise Ginseng::RequestError, e.message, e.backtrace
    end

    private

    def deep_merge(src, target)
      raise ArgumentError 'Not Hash' unless target.is_a?(Hash)
      dest = src.clone || {}
      target.each do |k, v|
        dest[k] = v.is_a?(Hash) ? deep_merge(dest[k], v) : v
      end
      return dest.compact
    end
  end
end
