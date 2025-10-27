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
      logger.info(h: 'channel', channel: channel.to_h, payload:)
    end
  end
end
