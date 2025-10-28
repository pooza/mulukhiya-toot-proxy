module Mulukhiya
  class ChannelNotificationHandler < Handler
    def disable?
      return true unless info_agent_service
      return true unless controller_class.channel?
      return super
    end

    def handle_post_toot(payload, params = {})
      return unless id = payload[:channelId]
      return unless channel = channel_class[id]
      return unless entry = search_entry(channel.name)
      return unless notify_to = account_class.get(acct: entry[:notify_to])
      notify(create_body(channel:, payload:), {accounts: [notify_to, sns.account]})
    rescue => e
      e.log
    end

    def channel_entries
      return (handler_config(:channels) || []).map(&:symbolize_keys)
    rescue => e
      e.log
      return []
    end

    private

    def create_body(params)
      body = []
      body.push("Channel: #{params[:channel].uri}")
      body.push("From: #{sns.account.acct}")
      params.dig(:payload, :text).each_line do |line|
        body.push("> #{line.chomp}")
      end
      return body.join("\n")
    end

    def search_entry(name)
      return channel_entries.find {|entry| entry[:name] == name}
    rescue => e
      e.log(name:)
      return nil
    end
  end
end
