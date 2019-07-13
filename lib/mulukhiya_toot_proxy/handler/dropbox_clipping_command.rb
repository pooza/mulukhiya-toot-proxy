module MulukhiyaTootProxy
  class DropboxClippingCommandHandler < CommandHandler
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
      uri = MastodonURI.parse(values['url'])
      return unless uri.id
      DropboxClippingWorker.perform_async(
        uri: {href: uri.to_s, class: uri.class.to_s},
        account_id: mastodon.account.id,
      )
    end
  end
end
