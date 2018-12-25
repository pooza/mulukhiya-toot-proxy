module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def dispatch(values)
      create_uris(values).each do |uri|
        next unless uri.valid?
        raise RequestError, "#{uri.class}: Invalid user ID" unless uri.id.present?
        begin
          uri.clip({growi: mastodon.growi})
        rescue RequestError
          uri.clip({
            growi: mastodon.growi,
            path: Growi.create_path(mastodon.account['username']),
          })
        end
      end
    end

    def create_uris(values)
      values['uri'] ||= values['url']
      raise RequestError, 'Empty URL' unless values['uri'].present?
      return [
        TwitterURI.parse(values['uri']),
        MastodonURI.parse(values['uri']),
      ].compact
    end
  end
end
