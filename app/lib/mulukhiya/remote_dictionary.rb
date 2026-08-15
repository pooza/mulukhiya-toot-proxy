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
      return "Mulukhiya::#{type(params).camelize}RemoteDictionary".constantize.new(params)
    rescue => e
      e.log
      return nil
    end

    # 設定の `type` を実装クラスの接頭辞へ揃える。未指定は `multi_field`、
    # `relative` は `related` の旧称。
    #
    # ⚠ **渡された params を書き換えないこと。** 以前はここで `params['type']` を
    # 直接埋めていたが、`handler_config(:dics)` が返すのは**プロセス共有の設定
    # ハッシュそのもの**。「一度 fetch を通したか」で設定の見え方が変わり、
    # TaggingDictionary の署名 (#4583) が writer と起動直後の reader で食い違って、
    # **新しいプロセスが毎回キャッシュを捨てて全辞書を同期取得していた**
    # （PR #4587 の Codex P2）。`initialize` は `params.key_flatten` で自前の
    # コピーを持つので、共有ハッシュを埋める必要はもともと無い。
    def self.type(params)
      type = params['type'] || 'multi_field'
      return type == 'relative' ? 'related' : type
    end

    private

    def create_entry(word)
      pattern = create_pattern(word)
      return {pattern:, regexp: pattern.source, words: [create_key(word)]}
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
        pattern = pattern.gsub(Regexp.new("[#{v}]"), "[#{v}]")
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
