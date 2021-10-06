module Mulukhiya
  class LemmyClippingCommandHandler < CommandHandler
    def disable?
      return true unless sns.account.lemmy
      return super
    end

    def exec
      return unless uri = Ginseng::URI.parse(parser.params['url'])
      return unless uri.absolute?
      if Environment.development? || Environment.test?
        LemmyClippingWorker.new.perform(uri: uri.to_s, account_id: sns.account.id)
      else
        LemmyClippingWorker.perform_async(uri: uri.to_s, account_id: sns.account.id)
      end
    end
  end
end
