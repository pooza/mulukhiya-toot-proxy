module Mulukhiya
  class MultiFieldTaggingResource < TaggingResource
    def parse
      result = {}
      fetch.each do |entry|
        fields.each do |field|
          next unless entry[field]
          result[create_key(entry[field])] ||= {pattern: create_pattern(entry[field])}
        end
      rescue => e
        @logger.error(Ginseng::Error.create(e).to_h.merge(resource: @params))
      end
      return result
    end

    def fields
      @fields ||= @params['/fields'] || ['word']
      return @fields
    end
  end
end
