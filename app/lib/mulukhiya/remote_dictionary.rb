module Mulukhiya
  class RemoteDictionary
    include Package

    def name
      return @params['/name'] || uri.path.split('/').last
    end

    def parse
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def fetch
      response = @http.get(uri).parsed_response
      raise 'empty' unless response.present?
      return response
    end

    def uri
      @uri ||= Ginseng::URI.parse(@params['/url'])
      return @uri
    end

    def edit_uri
      @edit_uri ||= Ginseng::URI.parse(@params['/edit/url'])
      return @edit_uri
    end

    def strict?
      return false
    end

    def to_h
      return {uri: uri.to_s}
    end

    def self.all(&block)
      return enum_for(__method__) unless block
      return unless handler = Handler.create(:dictionary_tag)
      handler.all.filter_map {|v| create(v)}.each(&block)
    end

    def self.create(params)
      params['type'] ||= 'multi_field'
      return "Mulukhiya::#{params['type'].camelize}RemoteDictionary".constantize.new(params)
    rescue => e
      e.log
      return nil
    end

    private

    def create_entry(word)
      pattern = create_pattern(word)
      return {pattern:, regexp: pattern.source, words: []}
    end

    def create_key(word)
      return word.nfkc
    end

    def create_pattern(word)
      pattern = word.nfkc.gsub(/[^[:alnum:]]/, '.? ?')
      [
        'あぁ', 'いぃ', 'うぅ', 'えぇ', 'おぉ', 'やゃ', 'ゆゅ', 'よょ',
        'アァ', 'イィ', 'ウゥ', 'エェ', 'オォ', 'ヤャ', 'ユュ', 'ヨョ'
      ].each do |v|
        pattern.gsub!(Regexp.new("[#{v}]"), "[#{v}]")
      end
      return Regexp.new(pattern)
    end

    def initialize(params)
      @params = params.key_flatten
      @http = HTTP.new
    end

    def retry_limit
      return config['/http/retry/limit'] rescue 5
    end
  end
end
