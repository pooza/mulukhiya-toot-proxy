module Mulukhiya
  class RelatedRemoteDictionary < RemoteDictionary
    def parse
      return fetch.to_h do |k, words|
        words = Array(words).map {|v| create_key(v)}
        words.unshift(create_key(k)) unless strict?
        words.uniq!
        [create_key(k), create_entry(k).merge(words:)]
      rescue => e
        e.log(dic: uri.to_s, word: k)
      end
    rescue => e
      e.log(dic: uri.to_s)
      return {}
    end

    def strict?
      return @params['/strict'] || false
    rescue => e
      e.log(dic: uri.to_s)
      rescue false
    end
  end
end
