module Mulukhiya
  # `format: regex` を**実際に**検証すること (#4597)。
  #
  # ⚠⚠ **json-schema には `regex` の検証実装がそもそも無い。**`format: regex` と
  # 書いてあっても `[unclosed` も `(?<broken` も素通しする。⚠ `validate_formats: true`
  # を渡しても変わらない。**フラグの問題ではない。**
  #
  # 🔴 いちばん効くのは `/sentry/scrub_patterns`。`before_send` の中で毎回
  # `Regexp.new` されるので、**Sentry へイベントを送ろうとした瞬間に初めて倒れる**
  # ＝ **例外を集める仕組みが例外で止まる**。設定した本人は「スクラブしているつもり」。
  class ConfigFormatValidatorTest < TestCase
    BROKEN = ['[unclosed', '(?<broken', '*invalid'].freeze

    # 🔴 **本体。**壊れた正規表現を捕まえる。
    def test_detects_a_broken_pattern
      BROKEN.each do |pattern|
        errors = validate({'spoiler' => {'pattern' => pattern}})

        assert_equal(1, errors.length, "#{pattern} を素通ししている")
        assert_match(%r{'#/spoiler/pattern'}, errors.first)
      end
    end

    # 🔴 **配列の中も見る。**`/sentry/scrub_patterns` はここ。
    def test_detects_a_broken_pattern_in_an_array
      errors = validate({'sentry' => {'scrub_patterns' => ['ok', '[unclosed', 'fine']}})

      assert_equal(1, errors.length)
      assert_match(%r{'#/sentry/scrub_patterns\[1\]'}, errors.first)
    end

    # 妥当なものは通す（機能を殺していない）。
    def test_accepts_valid_patterns
      values = {
        'spoiler' => {'pattern' => '\A(?<body>.+)\z'},
        'sentry' => {'scrub_patterns' => ['token=\w+', '[0-9]{4}']},
      }

      assert_empty(validate(values))
    end

    # ⚠ 未設定は検証対象ではない（schema の `required` の仕事）。
    def test_absent_values_are_not_errors
      assert_empty(validate({}))
    end

    # ⚠ `format: regex` 以外は触らない。`uri` は json-schema 側が見る。
    def test_other_formats_are_left_alone
      errors = validate({'status_url' => '[unclosed'})

      assert_empty(errors)
    end

    # ⚠⚠ **実際の schema に対して回しても落ちない**こと。ここが落ちるなら
    # 同梱の `config/schema` に壊れた既定値が入っている。
    def test_shipped_config_is_clean
      assert_empty(ConfigFormatValidator.new.errors)
    end

    # 🔴 **効かない format が復活していないこと。**`hostname` / `email` は
    # json-schema に検証実装が無く、`^/` は **format 名ですらなかった**（#4597）。
    # ⚠ **効かない指定を残すと「対応済み」に見えるだけ害になる。**
    #
    # ⚠ 通してよいのは 3 つだけ。`uri` / `date-time` は json-schema が見る。
    # **`regex` はここ（`ConfigFormatValidator`）が見る**ので残してよい。
    EFFECTIVE_FORMATS = ['uri', 'date-time', *ConfigFormatValidator::COMPILED_FORMATS].freeze

    def test_no_ineffective_formats_remain
      found = Dir.glob(File.join(Environment.dir, 'config/schema/**/*.yaml')).flat_map do |path|
        File.readlines(path).filter_map do |line|
          next unless matches = line.match(/^\s*format:\s*(\S+)\s*$/)
          "#{File.basename(path)}: #{matches[1]}" unless EFFECTIVE_FORMATS.include?(matches[1])
        end
      end

      assert_empty(found, '検証実装の無い format が残っている')
    end

    private

    def validate(values)
      return ConfigFormatValidator.new(Config.instance.schema, values).errors
    end
  end
end
