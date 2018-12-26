module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def dispatch(values)
      create_uris(values) do |uri|
        next unless uri && uri.id.present?
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
      yield TwitterURI.parse(values['uri'])
      yield MastodonURI.parse(values['uri'])
    end
  end
end
