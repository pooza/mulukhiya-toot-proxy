require 'addressable/uri'

module MulukhiyaTootProxy
  class NotificationWorker
    include Sidekiq::Worker

    def initialize
      @logger = Logger.new
      @db = Postgres.instance
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    private

    def connect_slack(id)
      uri = Addressable::URI.parse(UserConfigStorage.new[id]['/slack/webhook'])
      raise 'invalid URI' unless uri
      raise 'invalid URI' unless uri.absolute?
      return Slack.new(uri)
    rescue => e
      raise Ginseng::ConfigError, "Invalid webhook (#{e.message})"
    end

    def create_message(params)
      template = Template.new('notification')
      template[:account] = params[:account]
      template[:status] = params[:status]
      return template.to_s
    end
  end
end
