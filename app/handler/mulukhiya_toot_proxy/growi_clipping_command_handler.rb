module MulukhiyaTootProxy
  class GrowiClippingCommandHandler < CommandHandler
    def dispatch
      uri = Ginseng::URI.parse(@parser.params['url'])
      return unless uri.absolute?
      GrowiClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
