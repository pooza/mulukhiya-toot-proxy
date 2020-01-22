require 'unicode'

module Mulukhiya
  class TaggingResource
    def parse
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def fetch
      response = @http.get(uri).parsed_response
      raise 'empty' unless response.present?
      return response
    rescue => e
      raise Ginseng::GatewayError, "'#{url}' is invalid", e.backtrace
    end

    def uri
      @uri ||= Ginseng::URI.parse(@params['/url'])
      return @uri
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Config.instance['/tagging/dictionaries'].each do |dic|
        yield TaggingResource.create(dic)
      end
    end

    def self.create(params)
      params['type'] ||= 'multi_field'
      return "Mulukhiya::#{params['type'].camelize}TaggingResource".constantize.new(params)
    end

    private

    def create_key(word)
      return Unicode.nfkc(word)
    end

    def create_pattern(word)
      pattern = Unicode.nfkc(word).gsub(/[^[:alnum:]]/, '.? ?')
      [
        'あぁ', 'いぃ', 'うぅ', 'えぇ', 'おぉ', 'やゃ', 'ゆゅ', 'よょ',
        'アァ', 'イィ', 'ウゥ', 'エェ', 'オォ', 'ヤャ', 'ユュ', 'ヨョ'
      ].each do |v|
        pattern.gsub!(Regexp.new("[#{v}]"), "[#{v}]")
      end
      return Regexp.new(pattern)
    end

    def initialize(params)
      @params = Config.flatten('', params)
      @logger = Logger.new
      @http = HTTP.new
    end
  end
end
