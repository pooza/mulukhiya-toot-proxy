module Mulukhiya
  class NotificationWorker
    include Sidekiq::Worker

    def initialize
      @logger = Logger.new
      @db = Postgres.instance
      @config = Config.instance
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def template_name
      return 'toot_notification'
    end

    def create_message(params)
      template = Template.new(template_name)
      template[:account] = params[:account]&.to_h
      template[:toot] = params[:toot]&.to_h
      template[:status] = params[:status]
      template[:config] = @config
      return template.to_s
    end
  end
end
