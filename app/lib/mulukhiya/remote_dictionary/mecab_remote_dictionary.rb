module Mulukhiya
  class MecabRemoteDictionary < RemoteDictionary
    def parse
      result = {}
      fetch.each do |v|
        classes = v.slice(4..9)
        next unless classes.member?('固有名詞')
        next if classes.member?('姓')
        next if classes.member?('名')
        result[create_key(v.first)] = {pattern: create_pattern(v.first)}
      rescue => e
        @logger.error(error: e.message, dic: uri.to_s, entry: v)
      end
      return result
    rescue => e
      @logger.error(error: e.message, dic: uri.to_s)
      return {}
    end
  end
end
