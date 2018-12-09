require 'addressable/uri'

module MulukhiyaTootProxy
  class NotificationWorker
    include Sidekiq::Worker

    def perform(params)
      raise ImplementError, "'#{__method__}' not implemented"
    end

    private

    def connect_slack(id)
      uri = UserConfigStorage.new[id]['slack']['webhook']
      return nil unless uri
      uri = Addressable::URI.parse(uri)
      raise 'invalid URI' unless uri.absolute?
      return Slack.new(uri)
    rescue
      raise ConfigError, 'Invalid webhook (Slack compatible)'
    end

    def create_message(params)
      return [
        "From: #{params[:account]['display_name']} (@#{params[:account]['username']})",
        params[:status],
      ].join("\n")
    end

    def db
      return Postgres.instance
    end
  end
end
