module Mulukhiya
  class TaggingDictionary < Hash
    include Package
    include SNSMethods

    def initialize
      super
      @http = HTTP.new
      refresh unless cache.is_a?(Hash)
      update(cache)
    end

    def matches(source)
      text = source.dup
      tags = TagContainer.new
      reverse_each do |k, v|
        next if short?(k)
        next unless text.match?(v[:pattern])
        tags.add(k)
        tags.merge(v[:words])
        text.gsub!(v[:pattern], '')
      end
      return tags
    end

    def concat(values)
      values.each do |k, v|
        self[k] ||= v
        self[k][:words] ||= []
        self[k][:words].concat(v[:words]) if v[:words].is_a?(Array)
      rescue => e
        e.log(k: k, v: v)
      end
      update(sort_by {|k, _| k.length}.to_h)
    end

    def cache
      @cache ||= Marshal.load(redis['tagging_dictionary']) # rubocop:disable Security/MarshalLoad
      return @cache
    rescue => e
      e.alert
      return nil
    end

    def refresh
      redis['tagging_dictionary'] = Marshal.dump(merge(fetch))
      @cache = nil
      logger.info(class: self.class.to_s, method: __method__)
      clear
      update(cache)
    rescue => e
      e.alert
    end

    def short?(word)
      return false unless handler = Handler.create('dictionary_tag')
      pattern = Regexp.new("^#{handler.without_kanji_pattern}{,#{handler.minimum_length - 1}}$")
      return true if word.match?(pattern)
      return word.length < handler.minimum_length_kanji
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def fetch
      result = []
      RemoteDictionary.all.map do |dic|
        Thread.new do
          result.push(dic.parse)
        rescue => e
          e.alert(dic: {url: dic.uri.to_s})
        end
      end.each(&:join)
      return result
    end

    def merge(wordsets)
      result = {}
      wordsets.each do |words|
        words.each do |k, v|
          result[k] ||= v
          next unless v[:words].is_a?(Array)
          result[k][:words].concat(v[:words]).uniq!
        end
      end
      return result.sort_by {|k, _| k.length}.to_h
    end
  end
end
