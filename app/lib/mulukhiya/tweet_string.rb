require 'twitter-text'

module Mulukhiya
  class TweetString < String
    def length
      return each_char.map {|c| c.bytesize == 1 ? 0.5 : 1.0}.sum
    end

    def index(search)
      return nil if super.nil?
      return self[0..(super - 1)].length
    end

    def valid?
      return parsed[:valid]
    end

    def parse
      return Twitter::TwitterText::Validation.parse_tweet(self)
    end

    alias parsed parse
  end
end
