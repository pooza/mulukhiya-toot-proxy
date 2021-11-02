module Mulukhiya
  class DropboxClippingWorker < ClippingWorker
    def disable?
      return true unless controller_class.dropbox?
      return false
    end

    def perform(params = {})
      return unless account = account_class[params[:account_id]]
      return unless account.dropbox
      account.dropbox.clip(body: create_body(params))
    end
  end
end
