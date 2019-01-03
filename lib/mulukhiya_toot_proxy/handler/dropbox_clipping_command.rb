module MulukhiyaTootProxy
  class DropboxClippingCommandHandler < CommandHandler
    def dispatch(values)
      create_uris(values) do |uri|
        next unless uri&.id
        DropboxClippingWorker.perform_async({
          uri: {href: uri.to_s, class: uri.class.to_s},
          account: {id: mastodon.account_id},
        })
      end
    end

    private

    def create_uris(values)
      values['uri'] ||= values['url']
      raise RequestError, 'Empty URL' unless values['uri'].present?
      yield TwitterURI.parse(values['uri'])
      yield MastodonURI.parse(values['uri'])
    end
  end
end
