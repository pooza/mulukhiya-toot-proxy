module MulukhiyaTootProxy
  class ClippingCommandHandler < CommandHandler
    def worker_class
      return self.class.to_s.sub(/CommandHandler$/, 'Worker').constantize
    end

    def handle_pre_toot(body, params = {})
      return unless values = parse(body['status'])
      body['visibility'] = 'direct'
      body['status'] = create_status(values)
    end

    def handle_post_toot(body, params = {})
      return unless values = parse(body['status'])
      dispatch_command(values)
      @result.push(values)
    end

    def dispatch_command(values)
      create_uris(values) do |uri|
        next unless uri&.id
        worker_class.perform_async({
          uri: {href: uri.to_s, class: uri.class.to_s},
          account: {id: mastodon.account.id, username: mastodon.account.username},
        })
      end
    end

    private

    def create_uris(values)
      values['uri'] ||= values['url']
      values.delete('url')
      raise Ginseng::RequestError, 'Empty URL' unless values['uri'].present?
      yield MastodonURI.parse(values['uri'])
    end
  end
end
