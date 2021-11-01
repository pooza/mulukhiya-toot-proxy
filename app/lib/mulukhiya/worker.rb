module Mulukhiya
  class Worker
    include Sidekiq::Worker
    include Package
    include SNSMethods

    def self.perform_async(*args)
      if Environment.development? || Environment.test?
        new.perform(args)
      else
        client_push('class' => self, 'args' => args)
      end
    end
  end
end
