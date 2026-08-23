module Mulukhiya
  class RemoteDictionary
    include Package

    def name
      return @params['/name'] || uri.path.split('/').last
    end

    def parse
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    # ⚠ **`present?` だけでは 200-with-HTML を弾けない (#4573)。**HTTParty の
    # `parsed_response` は Content-Type が JSON でなければ **String をそのまま
    # 返す**。GAS の `/exec` は失効やアクセス権の変化で **HTTP 200 のまま
    # `text/html` のログイン誘導ページ**を返すため、HTTP 層は成功・`present?` も
    # 通り、`String#to_h` / `String#each` の NoMethodError として parse の奥で
    # 倒れて、外側の rescue が空の辞書に化けさせていた（美食丼の related 辞書 3 本が
    # 10 分周期で全滅していたのに誰も気付けなかった）。
    #
    # 型は**サブクラスが期待する形**で見る。読み辞書の
    # PronunciationDictionary#valid_schema? と同じく、外れたら型・Content-Type を
    # 添えて logger.error を残す。
    def fetch
      response = @http.get(uri)
      parsed = response.parsed_response
      # ⚠⚠ **URI を例外メッセージへ埋めない (#4630)。**`Ginseng::Logger#mask_url` は
      # `URL_PATTERN` を `\A` アンカーで見るので、マスクが効くのは
      # **値そのものが URL である文字列**だけ。文中に埋めると
      # `?access_token=` 付きの辞書 URL がそのまま syslog に残る。
      # ⚠ 同じ URL を `log_invalid_schema` の `url:` では `[FILTERED]` にしているのに
      # 例外メッセージ側だけ平文、という非対称になっていた。
      # URI はサブクラスの `e.log(dic: uri.to_s)`（マスクが効く）側に任せる。
      raise Ginseng::GatewayError, 'empty response' unless parsed.present?
      return parsed if valid_schema?(parsed)
      log_invalid_schema(response, parsed)
      raise Ginseng::GatewayError, "unexpected response type '#{parsed.class.name}'"
    end

    # サブクラスが `parse` で前提にしている型。
    def expected_class
      return Enumerable
    end

    def valid_schema?(parsed)
      return parsed.is_a?(expected_class)
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

    # ⚠ **本文そのものは残さない。**ログイン誘導ページには URL つきのトークンが
    # 載りうる (#4511)。型・Content-Type・サイズがあれば「JSON のはずが HTML を
    # 掴んでいる」は判別できる。
    def log_invalid_schema(response, parsed)
      logger.error(
        message: 'dictionary fetch schema invalid',
        url: uri.to_s,
        type: parsed.class.name,
        expected: expected_class.name,
        content_type: response.headers['content-type'],
        bytes: response.body.to_s.bytesize,
      )
    rescue => e
      e.log(dic: uri.to_s)
    end

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
