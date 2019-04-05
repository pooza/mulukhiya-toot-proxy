module MulukhiyaTootProxy
  class MultiFieldTaggingResource < TaggingResource
    def parse
      result = {}
      fetch.each do |entry|
        fields.each do |field|
          result[entry[field]] ||= {pattern: create_pattern(entry[field])}
        end
      rescue => e
        message = Ginseng::Error.create(e).to_h.clone
        message['resource'] = @params
        @logger.error(message)
        next
      end
      return result
    end

    def fields
      @fields ||= @params['/fields'] || ['word']
      return @fields
    end
  end
end
