module MulukhiyaTootProxy
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

    private

    def connect_slack(id)
      uri = Ginseng::URI.parse(Account.new({id: id}).config['/slack/webhook'])
      raise 'invalid URI' unless uri&.absolute?
      return Slack.new(uri)
    rescue => e
      raise Ginseng::ConfigError, "Invalid webhook (#{e.message})"
    end

    def create_message(params)
      template = Template.new('notification')
      template[:account] = params[:account].to_h
      template[:status] = params[:status]
      return template.to_s
    end
  end
end
