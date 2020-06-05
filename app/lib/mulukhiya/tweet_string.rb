module Mulukhiya
  class TweetString < String
    def length
      return each_char.map do |c|
        c.bytesize == 1 ? 0.5 : 1.0
      end.reduce(:+)
    end

    def index(search)
      return self[0..(super - 1)].length
    end
  end
end
