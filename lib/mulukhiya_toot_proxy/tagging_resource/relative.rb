module MulukhiyaTootProxy
  class RelativeTaggingResource < TaggingResource
    def parse
      return fetch.map do |k, v|
        [k, {pattern: create_pattern(k), words: v}]
      end.to_h
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h.concat({resource: @params}))
    end
  end
end
