module Mulukhiya
  class UserTagInitializeWorker
    include Sidekiq::Worker
    sidekiq_options retry: 3

    def perform
      UserConfigStorage.accounts do |account|
        next unless account.config['/tagging/user_tags'].present?
        account.config.update(tags: nil)
      end
    end
  end
end
