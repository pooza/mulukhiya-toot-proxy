module MulukhiyaTootProxy
  class DropboxClippingHandler < Handler
    def handle_post_toot(body, params = {})
      return unless body['status'] =~ /#dropbox/i
      DropboxClippingWorker.perform_async({
        body: body['status'],
        account: {id: mastodon.account_id},
      })
      @result.push(true)
    end

    def events
      return [:post_toot, :post_webhook]
    end
  end
end
