module Mulukhiya
  class NextcloudClippingCommandHandler < CommandHandler
    def disable?
      return true unless controller_class.nextcloud?
      return true unless sns.account&.nextcloud
      return super
    end

    def exec
      return unless uri = Ginseng::URI.parse(parser.params['url'])
      return unless uri.absolute?
      NextcloudClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
