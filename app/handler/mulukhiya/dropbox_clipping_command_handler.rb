module Mulukhiya
  class DropboxClippingCommandHandler < CommandHandler
    def dispatch
      uri = Ginseng::URI.parse(@parser.params['url'])
      return unless uri.absolute?
      DropboxClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
