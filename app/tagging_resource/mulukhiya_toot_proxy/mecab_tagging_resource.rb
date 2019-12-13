module MulukhiyaTootProxy
  class MecabTaggingResource < TaggingResource
    def parse
      result = {}
      fetch.each do |v|
        classes = v.slice(4..9)
        next unless classes.member?('固有名詞')
        next if classes.member?('姓')
        next if classes.member?('名')
        result[create_key(v.first)] = {pattern: create_pattern(v.first)}
      end
      return result
    rescue => e
      @logger.error(Ginseng::Error.create(e).to_h.merge(resource: @params))
      return {}
    end
  end
end
