module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def dispatch(values)
      values['uri'] ||= values['url']
      raise RequestError, 'Empty URL' unless values['uri'].present?
      if (uri = TwitterURI.parse(values['uri'])) && uri.twitter?
        raise RequestError, 'Invalid tweet ID' unless uri.tweet_id.present?
        uri.clip({growi: mastodon.growi, path: path})
      elsif (uri = MastodonURI.parse(values['uri'])) && uri.absolute?
        raise RequestError, 'Invalid toot ID' unless uri.toot_id.present?
        uri.clip({growi: mastodon.growi, path: path})
      end
    end

    def path
      @path ||= Growi.create_path(mastodon.account['username'])
      return @path
    end
  end
end
