module Mulukhiya
  class WebhookPayload
    attr_reader :raw

    def initialize(values)
      @raw = JSON.parse(values) unless values.is_a?(Hash)
      @raw ||= values.deep_stringify_keys
      @logger = Logger.new
    end

    def blocks?
      return blocks.is_a?(Array)
    end

    def blocks
      return @raw['blocks']
    end

    def attachments?
      return attachments.is_a?(Array)
    end

    def attachments
      return @raw['attachments']
    end

    def header
      return @raw['spoiler_text'] unless blocks?
      return blocks.find {|v| v['type'] == 'header'}.dig('text', 'text')
    rescue => e
      @logger.error(error: e, payload: raw)
      return nil
    end

    alias spoiler_text header

    def text
      return parse_legacy_text(@raw['text']) unless blocks?
      return blocks.find {|v| v['type'] == 'section'}.dig('text', 'text')
    rescue => e
      @logger.error(error: e, payload: raw)
      return nil
    end

    def images
      unless @images
        @images ||= blocks.select {|v| v['type'] == 'image'} if blocks?
        @images ||= attachments.select {|v| v['image_url'].present?} if attachments?
        @images ||= []
      end
      return @images
    rescue => e
      @logger.error(error: e, payload: raw)
      return []
    end

    def image_uris
      return images.map {|v| Ginseng::URI.parse(v['image_url'])}
    rescue => e
      @logger.error(error: e, payload: raw)
      return []
    end

    def values
      values = {Environment.controller_class.status_field => text}
      values[Environment.controller_class.spoiler_field] = header if header
      values['attachments'] = images
      return values
    end

    alias to_h values

    private

    def parse_legacy_text(text)
      temp = text.to_s
      temp.gsub!(':bell:', '🔔')
      text.to_s.scan(/(<(.*?)\|(.*?)>)/).each do |matches|
        pair, link, label = matches
        temp.gsub!(pair, "[ #{label} ](#{link})")
      end
      return temp
    rescue => e
      @logger.error(error: e, text: text)
      return text
    end
  end
end
