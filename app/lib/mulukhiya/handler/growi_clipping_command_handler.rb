module Mulukhiya
  class GrowiClippingCommandHandler < CommandHandler
    def disable?
      return true unless sns.account.growi
      return super
    end

    def exec
      uri = Ginseng::URI.parse(parser.params['url'])
      return unless uri.absolute?
      if Environment.development? || Environment.test?
        GrowiClippingWorker.new.perform(uri: uri.to_s, account_id: sns.account.id)
      else
        GrowiClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
      end
    end
  end
end
