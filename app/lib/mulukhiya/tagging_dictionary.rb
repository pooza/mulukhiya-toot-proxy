module Mulukhiya
  class TaggingDictionary < Hash
    def initialize
      super
      @config = Config.instance
      @logger = Logger.new
      @http = HTTP.new
      refresh unless exist?
      refresh if corrupted?
      load
    end

    def matches(body)
      r = []
      text = create_temp_text(body)
      reverse_each do |k, v|
        next if k.length < @config['/tagging/word/minimum_length']
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
        @logger.error(Ginseng::Error.create(e).to_h.merge(k: k, v: v))
      end
      update(sort_by {|k, v| k.length}.to_h)
    end

    def exist?
      return File.exist?(path)
    end

    def corrupted?
      return false unless load_cache.is_a?(Array)
      return true
    rescue TypeError, Errno::ENOENT => e
      @logger.error(class: self.class.to_s, path: path, message: e.message)
      return true
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/tagging_dictionary')
    end

    def load
      return unless exist?
      clear
      update(load_cache)
    end

    def refresh
      save_cache
      @logger.info(class: self.class.to_s, path: path, message: 'refreshed')
      load
    rescue => e
      @logger.error(e)
    end

    alias create refresh

    def delete
      File.unlink(path) if exist?
    end

    def remote_dics
      return enum_for(__method__) unless block_given?
      RemoteDictionary.all do |dic|
        yield dic
      end
    end

    private

    def fetch
      result = {}
      threads = []
      remote_dics do |dic|
        threads.push(Thread.new do
          dic.parse.each do |k, v|
            result[k] ||= v
            result[k][:words] ||= []
            result[k][:words].concat(v[:words]) if v[:words].is_a?(Array)
          rescue => e
            @logger.error(error: e.message, dic: dic.uri.to_s, word: k)
          end
        end)
      rescue => e
        @logger.error(error: e.message, dic: dic.uri.to_s)
      end
      threads.map(&:join)
      return result.sort_by {|k, v| k.length}.to_h
    end

    def create_temp_text(body)
      status = body[Environment.controller_class.status_field].clone
      status.gsub!(Acct.pattern, '')
      parts = [status]
      options = body.dig('poll', Environment.controller_class.poll_options_field)
      parts.concat(options) if options.present?
      return parts.join('::::')
    end

    def save_cache
      File.write(path, Marshal.dump(fetch))
      @cache = nil
    end

    def load_cache
      @cache ||= Marshal.load(File.read(path)) # rubocop:disable Security/MarshalLoad
      return @cache
    end
  end
end
