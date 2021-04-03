module Mulukhiya
  class LemmyClippingCommandHandler < CommandHandler
    def disable?
      #return true unless sns.account.lemmy
      return super
    end

    def exec
      #return unless uri = Ginseng::URI.parse(parser.params['url'])
      #return unless uri.absolute?
      #DropboxClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
