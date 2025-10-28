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

      logger.info(h: 'channel', channel: channel.to_h, entry:, payload:)
    end

    def channel_entries
      return (handler_config(:channels) || []).deep_symbolize_keys
    end

    private

    def search_entry(name)
      return channel_entries.find { |entry| entry[:name] == name }
    end
  end
end
