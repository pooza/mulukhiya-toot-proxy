module Mulukhiya
  class PiefedClippingCommandHandler < CommandHandler
    def disable?
      return true unless controller_class.piefed?
      return true unless sns.account&.piefed
      return super
    end

    def exec
      return unless uri = Ginseng::URI.parse(parser.params['url'])
      return unless uri.absolute?
      PiefedClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
    end
  end
end
