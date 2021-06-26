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

    def matches(body)
      r = []
      text = create_temp_text(body)
      reverse_each do |k, v|
        next if TaggingDictionary.short?(k)
        next unless text.match?(v[:pattern])
        r.push(k)
        r.concat(v[:words])
        text.gsub!(v[:pattern], '')
      end
      return r.uniq
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

    def create_temp_text(body)
      parts = [body[status_field], body[spoiler_field]]
      parts.push(body[chat_field]) if chat_field && body[chat_field]
      parts.concat(body.dig('poll', poll_options_field) || [])
      if ids = body[attachment_field]
        parts.concat(ids.map {|id| attachment_class[id]&.description})
      end
      return parts.map {|v| v.gsub(Acct.pattern, '')}.join('::::')
    end

    def fetch
      bar = ProgressBar.create(total: remote_dics.count)
      threads = []
      result = []
      remote_dics do |dic|
        thread = Thread.new do
          result.push(dic.parse)
        rescue => e
          logger.error(error: e, dic: {uri: dic.uri.to_s})
        ensure
          bar&.increment
        end
        threads.push(thread)
      end
      threads.each(&:join)
      bar&.finish
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
