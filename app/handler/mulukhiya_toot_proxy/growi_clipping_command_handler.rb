module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def handle_pre_toot(body, params = {})
      @parser = TootParser.new(body['status'])
      return unless @parser.exec
      body['visibility'] = 'direct'
      body['status'] = status
    end

    def handle_post_toot(body, params = {})
      @parser = TootParser.new(body['status'])
      return unless @parser.exec
      dispatch
      @result.push(@parser.params)
    end

    def dispatch
      uri = MastodonURI.parse(@parser.params['url'])
      return unless uri.id
      GrowiClippingWorker.perform_async(
        uri: {href: uri.to_s, class: uri.class.to_s},
        account_id: mastodon.account.id,
      )
    end
  end
end
