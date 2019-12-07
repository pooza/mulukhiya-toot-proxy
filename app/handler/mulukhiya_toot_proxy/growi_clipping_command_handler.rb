module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def handle_pre_toot(body, params = {})
      @parser = TootParser.new(body['status'])
      return unless @parser.exec
      return unless @parser.command_name == command_name
      errors = contract.call(@parser.params).errors.to_h
      raise Ginseng::RequestError, errors.values.join if errors.present?
      body['visibility'] = 'direct'
      body['status'] = status
    end

    def handle_post_toot(body, params = {})
      @parser = TootParser.new(body['status'])
      return unless @parser.exec
      return unless @parser.command_name == command_name
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
