module Mulukhiya
  class Worker
    include Sidekiq::Worker
    include Package
    include SNSMethods

    def disable?
      return false
    end

    def self.perform_async(*args)
      return if new.disable?
      if Environment.development? || Environment.test?
        args.push({}) unless args.present?
        args.each {|params| new.perform(params.deep_symbolize_keys)}
      else
        client_push('class' => self, 'args' => args.map(&:deep_symbolize_keys))
      end
    rescue => e
      Event.new(:alert).dispatch(e)
      raise e.message, e.backtrace
    end
  end
end
