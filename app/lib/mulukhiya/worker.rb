module Mulukhiya
  class Worker
    include Sidekiq::Worker
    include Package
    include SNSMethods

    def self.perform_async(*args)
      if Environment.development? || Environment.test?
        args.each {|params| new.perform(params.deep_symbolize_keys)}
      else
        client_push('class' => self, 'args' => args)
      end
    end
  end
end
