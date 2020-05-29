module Mulukhiya
  class RelativeRemoteDictionary < RemoteDictionary
    def parse
      return fetch.map do |k, words|
        words = [words] unless words.is_a?(Array)
        [create_key(k), {pattern: create_pattern(k), words: words.map {|word| create_key(word)}}]
      end.to_h
    rescue => e
      @logger.error(error: e.message, dic: uri.to_s)
      return {}
    end
  end
end
