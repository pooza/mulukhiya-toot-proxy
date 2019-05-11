module MulukhiyaTootProxy
  class ClippingCommandHandler < CommandHandler
    def worker_name
      return self.class.to_s.sub(/CommandHandler$/, 'Worker')
    end

    def dispatch_command(values)
      create_uris(values) do |uri|
        next unless uri&.id
        worker_name.constantize.perform_async({
          uri: {href: uri.to_s, class: uri.class.to_s},
          account: {id: mastodon.account_id, username: mastodon.account['username']},
        })
      end
    end

    def events
      return [:post_toot, :post_webhook]
    end

    private

    def create_uris(values)
      values['uri'] ||= values['url']
      values.delete('url')
      raise Ginseng::RequestError, 'Empty URL' unless values['uri'].present?
      yield TwitterURI.parse(values['uri'])
      yield MastodonURI.parse(values['uri'])
    end
  end
end
