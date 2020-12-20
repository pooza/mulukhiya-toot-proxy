module Mulukhiya
  class UserTagInitializeWorker
    include Sidekiq::Worker
    sidekiq_options retry: 3

    def perform
      UserConfigStorage.accounts do |account|
        next unless account.user_config['/tagging/user_tags'].present?
        account.user_config.update(tagging: {user_tags: nil})
      end
    end
  end
end
