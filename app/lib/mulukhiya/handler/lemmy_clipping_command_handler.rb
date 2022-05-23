module Mulukhiya
  class LemmyClippingCommandHandler < CommandHandler
    def toggleable?
      return false unless controller_class.lemmy?
      return false unless sns.account&.lemmy
      return super
    end

    def exec
      return unless uri = Ginseng::URI.parse(parser.params['url'])
      return unless uri.absolute?
      LemmyClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
