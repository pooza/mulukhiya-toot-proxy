module Mulukhiya
  class RemoteDictionary
    include Package

    # 語から正規表現を作る規則（`create_pattern`）の版。変えたら上げる。
    PATTERN_VERSION = 2
    # 前後の文字を見る短いカタカナの語の長さ (#4854)。
    KATAKANA_GUARD_MAX_LENGTH = 3

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

    # このソースを取り直す間隔（秒）。nil なら毎回取り直す (#4690)。
    #
    # ⚠ **数値以外・0 以下は「毎回」に倒す。**間隔を読み違えて取りに行かなくなる側へは倒さない
    # （型の間違いは `rake config:lint` が拾う）。
    def interval
      value = @params['/interval']
      return nil unless value.is_a?(Integer) && value.positive?
      return value
    end

    def to_h
      return {uri: uri.to_s}
    end

    # ソース単位の last-good キャッシュ (#4659) の同一性。
    #
    # ⚠⚠ **URL と型だけでは足りない（PR #4686 の Codex P2）。**`strict` のように
    # **解釈に効く**設定があり、同じ URL・同じ `type` でも `parse` が返す entries が
    # 変わる（`RelatedRemoteDictionary#strict?`）。キーを踏み合うと、**取得に失敗した
    # 回に別設定の辞書で埋めたものが本体キャッシュへ最大 24 時間居座る**。
    #
    # ⚠ **ハッシュにしてから使うこと。**`@params` には `?access_token=` 付きの URL が
    # 入る (#4511)。Redis のキー一覧は運用の手元にも syslog にも出る。
    #
    # ⚠ **`interval` は含めない（5.41.0 のリリース前レビュー）。**取得結果の解釈に効かない
    # 設定なので、含めると `interval` を足した・変えただけで last-good が別の鍵になり、
    # 直後の 1 回が上流の失敗に当たると埋め戻せない。
    #
    # ⚠ **`PATTERN_VERSION` を含める (#4854)。**last-good は作った正規表現ごと残るので、
    # 含めないと規則を変えたあと最大 24 時間、古い規則の辞書で埋め戻される。
    # ⚠ 本体キャッシュの署名（`TaggingDictionary#signature`）には含めない。含めると
    # 版を上げた直後の読み込みで本体を捨て、次の更新まで辞書タグが付かない。
    # 本体は次の定時の更新（10 分以内）で新しい規則の辞書に入れ替わる。
    # ⚠ ただし常に失敗するソースが 1 本でもあると、本体は据え置かれ、最大 24 時間は古い規則のまま。
    def cache_signature
      params = @params.reject {|key, _| key.to_s == '/interval'}
      return Digest::SHA256.hexdigest([self.class.name, PATTERN_VERSION, params.sort].to_json)
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
      return Regexp.new(guard_katakana_boundary(word.nfkc, pattern))
    end

    # ⚠⚠ **短いカタカナの語は、長いカタカナ語の中に当てない (#4854)。**本番 2 台の 30 日分では
    # ニコ⊂ニコニコ・シリー⊂シリーズ・ラリー⊂ギャラリー・キング⊂メタルキングコインのような
    # 当たりが gomander で 250 件あり、**3 文字以下の語はほぼ全部が誤爆**だった。
    # 先頭（末尾）がカタカナの語に限り、その側の隣がカタカナなら当てない。
    #
    # ⚠ **直前の「ー」は、その前がカタカナのときだけカタカナと見なす。**「やったーニコ」の
    # 「ー」まで見ると、正しい当たりを落とす（調査で唯一の取りこぼし）。
    # ⚠ 4 文字以上の語には掛けない。正しい当たり（キュアアンサーグリーティング）と誤爆が
    # 混ざっていて件数も少ないので、直すなら辞書の語の側で直す。
    # ⚠ **規則を変えたら `PATTERN_VERSION` を上げる。**ソースごとの last-good は作った
    # 正規表現ごと Redis に残る（`cache_signature`）。
    def guard_katakana_boundary(key, pattern)
      return pattern if KATAKANA_GUARD_MAX_LENGTH < key.length
      pattern = "(?<!\\p{Katakana}|\\p{Katakana}[ーｰ])#{pattern}" if key.match?(/\A\p{Katakana}/)
      pattern = "#{pattern}(?!\\p{Katakana}|[ーｰ])" if key.match?(/\p{Katakana}ー*\z/)
      return pattern
    end

    def initialize(params)
      @params = params.key_flatten
      # ⚠ **辞書だけ 404 を再送する (#4689)。**GAS の間欠 404 は「取れなかった」
      # ではなく相手側の一過性なので、last-good で埋める前に引き直す。
      # ⚠⚠ **`Mulukhiya::HTTP` 全体では開けない**（恒久的な 404 を 3 倍叩くだけ）。
      @http = DictionaryHTTP.new
    end
  end
end
