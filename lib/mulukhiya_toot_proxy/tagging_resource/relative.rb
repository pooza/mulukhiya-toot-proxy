module MulukhiyaTootProxy
  class RelativeTaggingResource < TaggingResource
    def parse
      return fetch.map do |k, words|
        words = [words] unless words.is_a?(Array)
        [create_key(k), {pattern: create_pattern(k), words: words.map{|word| create_key(word)}}]
      end.to_h
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h.merge(resource: @params))
      return {}
    end
  end
end
