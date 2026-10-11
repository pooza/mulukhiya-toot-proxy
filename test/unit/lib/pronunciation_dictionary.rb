module Mulukhiya
  class PronunciationDictionaryTest < TestCase
    ENTRIES = [
      {'surface' => '愛崎えみる', 'reading' => 'アイサキエミル', 'category' => '人名'},
      {'surface' => '閃華裂光拳', 'reading' => 'センカレッコウケン', 'category' => '技名'},
      {'surface' => 'アイス', 'reading' => 'アイス'},
    ].freeze

    def disable?
      PronunciationDictionary.new.redis.get('1')
      return super
    rescue
      return true
    end

    def setup
      return if disable?
      @dic = PronunciationDictionary.new
      @dic.redis[PronunciationDictionary::REDIS_KEY] = ENTRIES.to_json
    end

    def teardown
      @dic&.invalidate_cache
    end

    def test_suggest_by_hiragana_reading
      results = @dic.suggest('あいさき')

      assert_equal('愛崎えみる', results.first[:surface])
      assert_equal('アイサキエミル', results.first[:reading])
      assert_equal('人名', results.first[:category])
    end

    def test_suggest_passes_category_only_when_present
      entry = @dic.suggest('あいす').find {|r| r[:surface] == 'アイス'}

      assert_not_nil(entry)
      assert_false(entry.key?(:category))
    end

    def test_suggest_reading_prefix_match
      surfaces = @dic.suggest('あい').map {|r| r[:surface]}

      assert_includes(surfaces, '愛崎えみる')
      assert_includes(surfaces, 'アイス')
    end

    def test_suggest_orders_same_rank_by_reading
      # 同ランク (読み前方一致) 内は読みの五十音順で並ぶ。アイサ... < アイス。
      surfaces = @dic.suggest('あい').map {|r| r[:surface]}

      assert_equal(['愛崎えみる', 'アイス'], surfaces)
    end

    def test_suggest_empty_query_returns_empty
      assert_empty(@dic.suggest(''))
    end

    def test_all_returns_every_entry_in_present_format
      surfaces = @dic.all.map {|r| r[:surface]}

      assert_equal(ENTRIES.size, @dic.all.size)
      assert_includes(surfaces, '愛崎えみる')
      assert_includes(surfaces, '閃華裂光拳')
      assert_includes(surfaces, 'アイス')
      first = @dic.all.find {|r| r[:surface] == '愛崎えみる'}

      assert_equal('アイサキエミル', first[:reading])
      assert_equal('人名', first[:category])
    end

    def test_all_omits_category_when_absent
      entry = @dic.all.find {|r| r[:surface] == 'アイス'}

      assert_not_nil(entry)
      assert_false(entry.key?(:category))
    end

    def test_digest_is_stable_for_same_entries
      assert_equal(@dic.digest, PronunciationDictionary.new.digest)
    end

    def test_digest_changes_when_entries_change
      before = @dic.digest
      @dic.redis[PronunciationDictionary::REDIS_KEY] =
        (ENTRIES + [{'surface' => '相生', 'reading' => 'アイオイ'}]).to_json

      assert_not_equal(before, PronunciationDictionary.new.digest)
    end

    def test_suggest_respects_limit
      assert_operator(@dic.suggest('あい', limit: 1).size, :<=, 1)
    end

    def test_suggest_tolerates_non_scalar_limit
      # limit[]=1 のような配列・非数値でも 500 にせず既定動作へ倒す。
      assert_nothing_raised do
        @dic.suggest('あい', limit: ['1'])
        @dic.suggest('あい', limit: 'abc')
      end
    end

    def test_suggest_no_match_returns_empty
      assert_empty(@dic.suggest('ぞんざいしないよみ'))
    end

    def test_cold_cache_returns_empty_and_defers_fill_to_worker
      return if disable?
      url = 'https://dic.test/pron.json'
      original_urls = config['/word_suggest/urls']
      # fetch は SSRF allowlist を通る (#4410)。`.test` は解決できず fail-closed で
      # 弾かれるため、ここでは検証を通す callable に差し替える（teardown で復元）。
      original_validator = RemoteHost.validator
      RemoteHost.validator = ->(_host) {true}
      config['/word_suggest/urls'] = [url]
      stub_request(:head, url).to_return(status: 200)
      stub_request(:get, url).to_return(
        status: 200,
        body: [{'word' => '相生', 'pronunciation' => 'アイオイ'}].to_json,
        headers: {'Content-Type' => 'application/json'},
      )
      @dic.invalidate_cache

      # cold-cache の当該リクエストは同期 fetch せず空を即返す (#4405)。旧実装なら
      # ここで同期 fetch して候補が返るが、新実装は充填をワーカーへ委ねる。test モード
      # では perform_async が perform を同期実行するため、直後は別インスタンスから
      # 充填済みキャッシュで引ける。
      assert_empty(PronunciationDictionary.new.suggest('あいおい'))
      assert_equal('相生', PronunciationDictionary.new.suggest('あいおい').first[:surface])
    ensure
      config['/word_suggest/urls'] = original_urls if defined?(original_urls)
      RemoteHost.validator = original_validator if defined?(original_validator)
    end

    # 🔴 受信中に打ち切る (#4612)。上限を超えた本文は読み切る前に止まり、その URL は失敗扱い。
    # ⚠ `max_bytes:` を渡すのをやめると、受信後の実測（`exceeded max bytes`）に戻って落ちる。
    # ⚠⚠ 上流の `TooLargeError` は URL を文中に持つので、上へ渡さない（PR #4815 の Codex P1）。
    def test_fetch_is_cut_off_while_receiving
      return if disable?
      uri = Ginseng::URI.parse('https://dic.test/huge.json')
      original_validator = RemoteHost.validator
      original_max = config['/word_suggest/fetch/max_bytes']
      RemoteHost.validator = ->(_host) {'93.184.216.34'}
      config['/word_suggest/fetch/max_bytes'] = 16
      stub_request(:head, uri.to_s).to_return(status: 200)
      stub_request(:get, uri.to_s).to_return(
        status: 200,
        body: [{'word' => 'あ' * 100, 'pronunciation' => 'ア'}].to_json,
        headers: {'Content-Type' => 'application/json'},
      )

      logged = []
      logger = Object.new
      logger.define_singleton_method(:error) {|payload| logged.push(payload)}
      logger.define_singleton_method(:method_missing) {|*_args, **_kwargs| nil}
      @dic.define_singleton_method(:logger) {logger}

      assert_nil(@dic.send(:fetch_one, uri))
      assert_equal(['word_suggest fetch cut off while receiving'], logged.filter_map {|v| v[:message]})
      assert_equal(uri.to_s, logged.first[:url])
    ensure
      config['/word_suggest/fetch/max_bytes'] = original_max if defined?(original_max)
      RemoteHost.validator = original_validator if defined?(original_validator)
    end

    # GAS は HEAD に 403 を返す。黙って GET へ倒すと決めているので、上流（Ginseng::HTTP）の
    # 「落ちた試行」の行も出さない (#4793)。gomander で 1 日 144 行出ていた。
    # ⚠ 5xx は想定外なので行が残ること。
    def test_head_not_supported_leaves_no_upstream_error_line
      return if disable?
      uri = Ginseng::URI.parse('https://dic.test/pron.json')
      original_validator = RemoteHost.validator
      RemoteHost.validator = ->(_host) {'93.184.216.34'}
      logged = []
      logger = Object.new
      logger.define_singleton_method(:error) {|payload| logged.push(payload)}
      logger.define_singleton_method(:method_missing) {|*_args, **_kwargs| nil}
      @dic.instance_variable_get(:@http).instance_variable_set(:@logger, logger)
      {403 => false, 405 => false, 500 => true}.each do |status, expected|
        logged.clear
        stub_request(:head, uri.to_s).to_return(status:)

        assert(@dic.send(:valid_content_length?, uri), "HEAD #{status}")
        assert_equal(expected, logged.any? {|v| v[:method] == :HEAD}, "HEAD #{status}")
      end
    ensure
      RemoteHost.validator = original_validator if defined?(original_validator)
    end
  end
end
