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
      body = create_body(channel:, payload:)
      notify_to_accounts(entry).each do |account|
        info_agent_service.notify(account, body)
      end
    rescue => e
      e.log
    end

    def channel_entries
      return (handler_config(:channels) || []).map(&:symbolize_keys)
    rescue => e
      e.log
      return []
    end

    def notify_to_accounts(entry)
      accts = Array(entry[:notify_to])
      return accts.filter_map {|acct| account_class.get(acct:)}
    end

    private

    def create_body(params)
      body = []
      body.push("Channel: #{params[:channel].uri}")
      body.push("From: #{sns.account.display_name}")
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
