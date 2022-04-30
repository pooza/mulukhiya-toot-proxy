module Mulukhiya
  module StatusMethods
    def parser
      @parser ||= parser_class.new(text || '')
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

    def public?
      return visibility == controller_class.visibility_name(:public)
    end

    def taggable?
      return false unless public?
      return true
    end
  end
end
