module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def initialize
      super
      Sidekiq.configure_client do |config|
        config.redis = {url: @config['/sidekiq/redis/dsn']}
      end
    end

    def dispatch(values)
      create_uris(values) do |uri|
        next unless uri&.id
        GrowiClippingWorker.perform_async({
          uri: {href: uri.to_s, class: uri.class.to_s},
          account: mastodon.account_id,
        })
      end
    end

    def create_uris(values)
      values['uri'] ||= values['url']
      raise RequestError, 'Empty URL' unless values['uri'].present?
      yield TwitterURI.parse(values['uri'])
      yield MastodonURI.parse(values['uri'])
    end
  end
end
