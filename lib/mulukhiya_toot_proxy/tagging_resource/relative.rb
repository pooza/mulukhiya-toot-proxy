module MulukhiyaTootProxy
  class RelativeTaggingResource < TaggingResource
    def parse
      return fetch.map do |k, v|
        [k, {pattern: create_pattern(k), words: v}]
      rescue => e
        message = Ginseng::Error.create(e).to_h.clone
        message['resource'] = @params
        @logger.error(message)
        next
      end.to_h
    end
  end
end
