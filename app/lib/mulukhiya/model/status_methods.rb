module Mulukhiya
  module StatusMethods
    def parser
      @parser ||= parser_class.new(text)
      return @parser
    end

    def body
      return parser.body
    end

    def footer
      return parser.footer
    end

    def footer_tags
      return parser.footer_tags.filter_map {|tag| hash_tag_class.get(tag:)}
    end

    def visibility_icon
      return parser_class.visibility_icon(visibility_name)
    end

    def data
      @data ||= service.fetch_status(id).parsed_response.deep_symbolize_keys
      return @data
    end

    def poll
      return nil
    end

    def webui_uri
      @webui_uri ||= service.create_uri("/mulukhiya/app/status/#{id}")
      return @webui_uri
    end

    def public?
      return visibility == controller_class.visibility_name(:public)
    end

    def nowplaying?
      return text.match?(/#nowplaying/i)
    end

    def poipiku?
      return parser.uris.any? {|v| PoipikuURI.parse(v).poipiku? rescue false}
    end

    def taggable?
      return false unless public?
      return true
    end

    def payload
      payload = values.slice(
        reply_to_field.to_sym,
        spoiler_field.to_sym,
        visibility_field.to_sym,
      )
      payload[status_field.to_sym] = text
      return payload
    end

    def to_h
      @hash ||= values.deep_symbolize_keys.merge(
        body:,
        created_at: date&.getlocal&.strftime('%Y/%m/%d %H:%M:%S'),
        footer_tags: footer_tags.map(&:to_h),
        footer:,
        id: id.to_s,
        is_taggable: taggable?,
        is_nowplaying: nowplaying?,
        is_poipiku: poipiku?,
        public_url: public_uri.to_s,
        uri: uri.to_s,
        url: uri.to_s,
        visibility_icon:,
        visibility_name:,
        webui_url: webui_uri.to_s,
      ).compact
      return @hash
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def default
        return {
          spoiler: {
            text: spoiler_text,
            emoji: spoiler_emoji,
            shortcode: spoiler_shortcode,
          },
          default_hashtag:,
        }
      end

      def spoiler_text
        return config["/#{Environment.controller_name}/status/spoiler_text"] rescue nil
      end

      def spoiler_emoji
        return config['/spoiler/emoji'] rescue nil
      end

      def spoiler_shortcode
        return nil unless emoji = spoiler_emoji
        return ":#{emoji}:"
      end

      def spoiler_pattern
        return Regexp.new(config['/spoiler/pattern'])
      end

      def default_hashtag
        return nil unless handler = Handler.create(:default_tag)
        return nil unless tag = handler.handler_config(:tags)&.first
        return tag.to_hashtag
      end
    end
  end
end
