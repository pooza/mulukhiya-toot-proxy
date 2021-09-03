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
      tags = TagContainer.new
      text = create_temp_text(source)
      reverse_each do |k, v|
        next if TaggingDictionary.short?(k)
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
        logger.error(error: e, k: k, v: v)
      end
      update(sort_by {|k, _| k.length}.to_h)
    end

    def cache
      @cache ||= Marshal.load(redis['tagging_dictionary']) # rubocop:disable Security/MarshalLoad
      return @cache
    rescue => e
      logger.error(error: e)
      return nil
    end

    def refresh
      redis['tagging_dictionary'] = Marshal.dump(merge(fetch))
      @cache = nil
      logger.info(class: self.class.to_s, message: 'refreshed')
      clear
      update(cache)
    rescue => e
      logger.error(error: e)
    end

    def remote_dics(&block)
      return enum_for(__method__) unless block
      RemoteDictionary.all(&block)
    end

    def self.short?(word)
      return true if word.match?("^#{without_kanji_pattern}{,#{minimum_length - 1}}$")
      return word.length < minimum_length_kanji
    end

    def self.without_kanji_pattern
      return config['/tagging/word/without_kanji_pattern']
    end

    def self.minimum_length
      return config['/tagging/word/minimum_length']
    end

    def self.minimum_length_kanji
      return config['/tagging/word/minimum_length_kanji']
    end

    private

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def create_temp_text(payload)
      return payload if payload.is_a?(String)
      parts = [payload[status_field], payload[spoiler_field], payload[chat_field]]
      parts.concat(payload.dig('poll', poll_options_field) || [])
      (payload[attachment_field] || []).each do |id|
        next unless attachment = attachment_class[id]
        parts.push(attachment.description)
      rescue => e
        logger.error(error: e)
      end
      return parts.compact.map {|v| v.gsub(Acct.pattern, '')}.join('::::')
    end

    def fetch
      threads = []
      result = []
      remote_dics do |dic|
        thread = Thread.new do
          result.push(dic.parse)
        rescue => e
          logger.error(error: e, dic: {uri: dic.uri.to_s})
        end
        threads.push(thread)
      end
      threads.each(&:join)
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
