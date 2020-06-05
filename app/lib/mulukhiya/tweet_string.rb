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

    def self.config
      return Config.instance
    end

    def self.max_length
      suffixes = ['あ' * config['/twitter/status/length/url'], ' ']
      suffixes.concat(tags)
      return config['/twitter/status/length/max'] - TweetString.new(suffixes.join(' ')).length.ceil
    end

    def self.tags
      return config['/twitter/status/tags'].map {|tag| MastodonService.create_tag(tag)}
    rescue
      return []
    end
  end
end
