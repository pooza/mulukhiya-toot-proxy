module MulukhiyaTootProxy
  class RelativeTaggingResource < TaggingResource
    def parse
      return fetch.map do |k, v|
        [k, {pattern: create_pattern(k), words: v}]
      end.to_h
    rescue => e
      message = Ginseng::Error.create(e).to_h.clone
      message['resource'] = @params
      @logger.error(message)
    end
  end
end
