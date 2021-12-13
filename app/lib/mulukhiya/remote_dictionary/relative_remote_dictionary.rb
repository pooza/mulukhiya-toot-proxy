module Mulukhiya
  class RelativeRemoteDictionary < RemoteDictionary
    def parse
      return fetch.to_h do |k, words|
        [create_key(k), create_entry(k).merge(words: Array(words).map {|v| create_key(v)})]
      rescue => e
        e.log(dic: uri.to_s, word: k)
      end
    rescue => e
      e.log(dic: uri.to_s)
      return {}
    end
  end
end
