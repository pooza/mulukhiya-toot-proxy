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

    def webui_uri
      @webui_uri ||= service.create_uri("/mulukhiya/app/status/#{id}")
      return @webui_uri
    end

    def public?
      return visibility == controller_class.visibility_name(:public)
    end

    def taggable?
      return false unless public?
      return true
    end

    def to_h
      @hash ||= values.deep_symbolize_keys.merge(
        body:,
        created_at: date&.strftime('%Y/%m/%d %H:%M:%S'),
        footer_tags: footer_tags.map(&:to_h),
        footer:,
        id: id.to_s,
        is_taggable: taggable?,
        public_url: public_uri.to_s,
        uri: uri.to_s,
        url: uri.to_s,
        visibility_icon:,
        visibility_name:,
        webui_url: webui_uri.to_s,
      ).compact
      return @hash
    end
  end
end
