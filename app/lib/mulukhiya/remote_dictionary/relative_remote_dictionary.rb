module Mulukhiya
  class RelativeRemoteDictionary < RemoteDictionary
    def parse
      return fetch.map do |k, words|
        words = Array(words)
        [create_key(k), create_entry(k).merge(words: words.map {|v| create_key(v)})]
      rescue => e
        logger.error(error: e, dic: uri.to_s, word: k)
      end.to_h
    rescue => e
      logger.error(error: e, dic: uri.to_s)
      return {}
    end
  end
end
