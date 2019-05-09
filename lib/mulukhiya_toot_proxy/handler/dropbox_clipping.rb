module MulukhiyaTootProxy
  class DropboxClippingHandler < Handler
    def handle_pre_toot(body, params = {})
      return unless body['status'] =~ /#dropbox/i
      DropboxClippingWorker.perform_async({
        body: body['status'],
        account: {id: mastodon.account_id},
      })
      @result.push(true)
    end
  end
end
