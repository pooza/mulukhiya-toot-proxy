require 'zlib'

module Mulukhiya
  class TweetString < String
    def initialize(value)
      @config = Config.instance
      super
    end

    def length
      return each_char.map do |c|
        c.bytesize == 1 ? 0.5 : 1.0
      end.reduce(:+)
    end

    def index(search)
      return self[0..(super - 1)].length
    end

    def tweetablize(length)
      links = {}
      text = clone
      Ginseng::URI.scan(text).each do |uri|
        pos = text.index(uri.to_s)
        if (length - @config['/twitter/status/length/url'] - 0.5) < pos
          text.ellipsize!(pos - 0.5)
          break
        end
        key = Zlib.adler32(uri.to_s)
        links[key] = uri.to_s
        text.sub!(uri.to_s, create_tag(key))
      end
      text.ellipsize!(length)
      links.each do |key, link|
        text.sub!(create_tag(key), link)
      end
      return text
    end

    def tweetablize!(length)
      replace(tweetablize(length))
      return self
    end

    private

    def create_tag(key)
      return '{crc:%0' + (@config['/twitter/status/length/url'] - 9).to_s + 'd}' % key
    end
  end
end
