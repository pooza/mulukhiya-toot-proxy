module Mulukhiya
  class TaggingDictionary < Hash
    include Package
    include SNSMethods

    def initialize
      super
      @handler = Handler.create(:dictionary_tag)
      @http = HTTP.new
      refresh unless cache.is_a?(Hash)
      update(cache)
    end

    def clear
      @cache = nil
      super
    end

    def matches(source)
      text = source.dup
      tags = Concurrent::Array.new
      chunks.reverse_each do |chunk|
        Parallel.each(chunk.keys, in_threads: Parallel.processor_count) do |k|
          next unless text.match?(chunk.dig(k, :pattern))
          tags.merge(chunk.dig(k, :words))
          text = text.gsub(chunk.dig(k, :pattern), '')
        rescue => e
          e.log(entry:)
        end
      end
      return TagContainer.new(tags.uniq)
    end

    def chunks
      chunks = Concurrent::Hash.new
      Parallel.each(keys, in_threads: Parallel.processor_count) do |k|
        next if short?(k)
        chunks[k.length] ||= Concurrent::Hash.new
        chunks[k.length][k] = self[k]
      rescue => e
        e.log(k:)
      end
      return chunks.sort_by {|k, _| k}
    end

    def concat(values)
      values.each do |k, v|
        self[k] ||= v
        self[k][:words] ||= []
        self[k][:words].concat(v[:words]) if v[:words].is_a?(Array)
      rescue => e
        e.log(k:, v:)
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
      clear
      redis['tagging_dictionary'] = Marshal.dump(merge(fetch))
      update(cache)
    rescue => e
      e.alert
    end

    def short?(word)
      pattern = Regexp.new("^#{@handler.without_kanji_pattern}{,#{@handler.minimum_length - 1}}$")
      return true if word.match?(pattern)
      return word.length < @handler.minimum_length_kanji
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def fetch
      result = Concurrent::Array.new
      Parallel.each(RemoteDictionary.all, in_threads: Parallel.processor_count) do |dic|
        words = dic.parse
        logger.info(dic: dic.to_h.merge(words: words.count))
        result.push(words)
      rescue => e
        e.log(dic: dic.to_h)
      end
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
