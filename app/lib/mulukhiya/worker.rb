module Mulukhiya
  class Worker
    include Sidekiq::Worker
    include Package
    include SNSMethods

    def disable?
      return false
    end

    def underscore
      return self.class.to_s.split('::').last.sub(/Worker$/, '').underscore
    end

    def worker_config(*keys)
      path = keys.map(&:to_s).join('/')
      value = config["/worker/#{underscore}/#{path}"] rescue nil
      value = config["/worker/default/#{path}"] rescue nil if value.nil?
      return value
    end

    def initialize_params(params)
      return unless params.present?
      params.deep_symbolize_keys!
      log(params:)
    end

    def log(message)
      logger.info({worker: underscore, jid:}.merge(message))
    end

    def self.create(name)
      return "Mulukhiya::#{name.to_s.sub(/_worker$/, '').camelize}Worker".constantize.new
    rescue => e
      e.log(name:)
      return nil
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
      e.alert
      raise e.message, e.backtrace
    end
  end
end
