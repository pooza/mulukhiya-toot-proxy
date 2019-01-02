module MulukhiyaTootProxy
  class DropboxClippingHandler < Handler
    def exec(body, headers = {})
      return unless body['status'] =~ /#dropbox/i
      DropboxClippingWorker.perform_async({
        body: body['status'],
        account: {id: mastodon.account_id},
      })
      increment!
    end
  end
end
