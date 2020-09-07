module Mulukhiya
  class WebhookPayload
    attr_reader :raw

    def initialize(values)
      @raw = JSON.parse(values) unless values.is_a?(Hash)
      @raw ||= values.deep_stringify_keys
    end

    def blocks?
      return @raw['blocks'].is_a?(Array)
    end

    def blocks
      return @raw['blocks']
    end

    def header
      return @raw['spoiler_text'] unless blocks?
      return blocks.find {|v| v['type'] == 'header'}.dig('text', 'text')
    end

    alias spoiler_text header

    def text
      return @raw['text'] unless blocks?
      return blocks.find {|v| v['type'] == 'section'}.dig('text', 'text')
    end

    def images
      unless @images
        @images = @raw['attachments'] unless blocks?
        @images ||= blocks.select {|v| v['type'] == 'image'} if blocks
        @images ||= []
      end
      return @images
    end

    def image_uris
      return images.map {|v| Ginseng::URI.parse(v['image_url'])}
    end

    def values
      values = {Environment.controller_class.status_field => text}
      values[Environment.controller_class.spoiler_field] = header if header
      values['attachments'] = images
      return values
    end

    alias to_h values
  end
end
