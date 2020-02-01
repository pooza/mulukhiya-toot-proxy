module Mulukhiya
  class BookmarkDropboxClippingHandler < Handler
    def handle_post_bookmark(body, params = {})
      return unless uri = Environment.status_class[body[status_key]].uri
      return unless uri.absolute?
      DropboxClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
      @result.push(url: uri.to_s)
    end

    def notifiable?
      return true
    end
  end
end
