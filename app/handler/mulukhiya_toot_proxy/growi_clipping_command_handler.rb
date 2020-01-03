module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def handle_pre_toot(body, params = {})
      @parser = MessageParser.new(body[message_field])
      return unless @parser.exec
      return unless @parser.command_name == command_name
      errors = contract.call(@parser.params).errors.to_h
      raise Ginseng::ValidateError, errors.values.join if errors.present?
      body['visibility'] = 'direct'
      body[message_field] = status
    end

    def handle_post_toot(body, params = {})
      @parser = MessageParser.new(body[message_field])
      return unless @parser.exec
      return unless @parser.command_name == command_name
      dispatch
      @result.push(@parser.params)
    end

    def dispatch
      uri = Ginseng::URI.parse(@parser.params['url'])
      return unless uri.absolute?
      GrowiClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
