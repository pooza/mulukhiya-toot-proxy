module Mulukhiya
  class RelativeRemoteDictionary < RemoteDictionary
    def parse
      return fetch.to_h do |k, words|
        words = Array(words)
        [create_key(k), create_entry(k).merge(words: words.map {|v| create_key(v)})]
      rescue => e
        logger.error(error: e, dic: uri.to_s, word: k)
      end
    rescue => e
      logger.error(error: e, dic: uri.to_s)
      return {}
    end
  end
end
