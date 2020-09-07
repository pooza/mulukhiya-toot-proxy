require 'twitter-text'

module Mulukhiya
  class TweetString < String
    def initialize(string)
      @config = Config.instance
      super
    end

    def length
      return each_char.map {|c| c.bytesize == 1 ? 0.5 : 1.0}.sum
    end

    def index(search)
      return nil if super.nil?
      return self[0..(super - 1)].length
    end

    def valid?
      return parse[:valid]
    end

    def tweetablize
      return TweetString.new(ellipsize(body_length_limit))
    end

    def extra_tags
      unless @extra_tags
        container = TagContainer.new
        container.text = self
        container.concat(default_tags)
        container.concat(hot_tags)
        @extra_tags = container.create_tags
      end
      return @extra_tags
    end

    def body_length_limit
      suffixes = ['', 'あ' * @config['/twitter/status/length/url']].concat(extra_tags)
      return max_length - TweetString.new(suffixes.join('  ')).length.ceil
    end

    private

    def max_length
      return @config['/twitter/status/length/max']
    end

    def parse
      @parsed ||= Twitter::TwitterText::Validation.parse_tweet(self)
      return @parsed
    end

    def exist_tags
      @exist_tags ||= Twitter::TwitterText::Extractor.extract_hashtags(self).map(&:to_tag_base)
      return @exist_tags
    end

    def hot_tags
      unless @hot_tags
        temp = clone
        tags = []
        @config['/twitter/status/hot_words'].sort_by(&:length).reverse_each do |v|
          next unless temp.match?(v)
          tags.push(v)
          temp.gsub!(v, '')
        end
        @hot_tags = tags.compact.uniq
      end
      return @hot_tags
    end

    def default_tags
      return @config['/twitter/status/tags']
    rescue Ginseng::ConfigError
      return []
    end
  end
end
