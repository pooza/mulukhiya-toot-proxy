module Mulukhiya
  # gem 境界のテスト (#4616)。
  #
  # ログのマスクは **モロヘイヤの config（`/logger/mask_fields` /
  # `/logger/mask_query_params`）と ginseng-core の実装の合わせ技**で成立している。
  # かつて `Logger#mask_url` は不正なバイト列を含む値で `ArgumentError` を上げ、
  # それが `create_message` の rescue まで飛んで **素の src がそのまま返る ＝
  # マスクが丸ごと外れる**状態だった (pooza/ginseng-core#518)。
  #
  # ⚠⚠ **`Controller#before` は受信 params をそのまま `logger.info` に載せる**ので、
  # **外から壊れたバイト列を 1 つ混ぜるだけでその行のマスクを外せた。**#4511 で
  # 掃討したはずのトークン平文が、この経路で戻っていたことになる。
  #
  # ⚠ `log_scrub` の側（`SCRUBBED_LOG_PARAMS`）は gem を通らないので、この退行を
  # 捕まえられない。**gem が「何を出力するか」**を押さえるのはこのファイルの役目。
  # bundle update で黙って戻る類なので、上流の実装ではなく境界の契約として残す。
  #
  # ⚠ **モロヘイヤの実 config で実測した 1.17.0 の出力**（同じ入力・同じ config）:
  #
  # ```
  # {"password":"hoge","url":"https://example.com/?access_token=SECRET&s=\xE3\x81ho"}
  # ```
  #
  # **`password` も `access_token` も平文**で、行そのものも妥当な UTF-8 ではなかった。
  # 1.19.0 では同じ入力が `[FILTERED]` ＋ `_encoding_error: true` になる。
  class LoggerMaskBoundaryTest < TestCase
    # ⚠ **不正な UTF-8 バイト列。**`"\xE3\x81"` は 3 バイト文字の途中で切れている。
    BROKEN = "\xE3\x81ho".dup.force_encoding(Encoding::UTF_8).freeze

    def setup
      @logger = Logger.new
    end

    def entry(src)
      return @logger.create_entry(src)
    end

    # 眼目。壊れたバイト列が混ざっても、マスクは外れない。
    def test_mask_survives_broken_bytes
      line = entry(password: 'hoge', url: "https://example.com/?access_token=SECRET&s=#{BROKEN}")

      assert_not_match(/hoge/, line)
      assert_not_match(/SECRET/, line)
    end

    # ⚠ 行が消えるのも困る（ログは最後の観測手段）。落とさずに 1 行出すこと。
    def test_broken_bytes_still_produce_a_line
      line = entry(url: "https://example.com/?s=#{BROKEN}")

      assert_true(line.present?)
      assert_true(line.valid_encoding?)
    end

    # ⚠ 直したことを隠さない。JSON として読む側が「直った行」と分かる印。
    def test_broken_bytes_are_flagged
      assert_match(/_encoding_error/, entry(url: "https://example.com/?s=#{BROKEN}"))
    end

    # ⚠ **`logger.info(url)` はいちばん自然な呼び方**なので経路として太い
    # (pooza/ginseng-core#529)。Hash 以外でもマスクを通ること。
    def test_masks_bare_string
      assert_not_match(/SECRET/, entry('https://example.com/?access_token=SECRET'))
    end

    # 壊れていない側の退行検知（上の 4 本が「全部伏せる」で通ってしまわないように）。
    def test_masks_normal_input
      line = entry(password: 'hoge', url: 'https://example.com/?access_token=SECRET&q=1')

      assert_not_match(/hoge/, line)
      assert_not_match(/SECRET/, line)
      assert_match(/example\.com/, line)
    end

    # マスク対象外まで消さない（ログが役に立たなくなるため）。
    def test_keeps_other_values
      assert_match(/note-id/, entry(note: 'note-id'))
    end
  end
end
