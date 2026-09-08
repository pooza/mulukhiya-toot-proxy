module Mulukhiya
  # `Mulukhiya.validate_config` の strict が**実際に起動を止める**こと (#4596)。
  #
  # ⚠⚠ **直す前は「strict を書いたのに止まらない」だった。**`raise` が同じメソッドの
  # `rescue => e` に捕まっていて（`Ginseng::ConfigError < Ginseng::Error < StandardError`）、
  # 構造的に発火しなかった。⚠ **fail-open ガードは「素通りする」テストだけでは守れない**
  # ので、ここは **実際にブロックする正テスト**を主役に置く。
  class ConfigValidationTest < TestCase
    STRICT_KEY = '/config/validation/strict'.freeze
    DUMMY_ERRORS = ["The property '#/dummy' did not contain a required property"].freeze

    def setup
      @strict = config[STRICT_KEY] rescue nil
    end

    def teardown
      config[STRICT_KEY] = @strict
      restore_errors
    end

    # 🔴 **本体。**strict が真で検証エラーがあるなら、例外が**外へ出る**。
    def test_strict_raises_when_errors_exist
      stub_errors(DUMMY_ERRORS)
      config[STRICT_KEY] = true

      captured = capture_stderr do
        assert_raises(Ginseng::ConfigError) {Mulukhiya.validate_config}
      end

      # ⚠ **退行の目印はこの文字列。**「失敗した」と「飛ばした」が 1 行に同居していたら、
      # また自分の rescue が raise を握っている。
      assert_not_match(/config validation skipped: config validation failed/, captured)
    end

    # strict が偽なら、エラーがあっても警告だけで起動は続く（既定の振る舞い）。
    def test_non_strict_only_warns
      stub_errors(DUMMY_ERRORS)
      config[STRICT_KEY] = false

      captured = capture_stderr {assert_nil(Mulukhiya.validate_config)}

      assert_match(/config validation: /, captured)
    end

    # ⚠⚠ **strict のキーが引けない環境でも、その 1 点だけで検証は飛ばない。**
    # `Ginseng::Config#[]` は未定義パスで ConfigError を上げるので、以前はここで
    # 検証そのものが落ちていた ＝ **設定パスの typo がガードの恒常 no-op に化けた**。
    def test_validation_runs_without_the_strict_key
      stub_errors(DUMMY_ERRORS)
      config[STRICT_KEY] = nil
      assert_raises(Ginseng::ConfigError) {config[STRICT_KEY]}

      captured = capture_stderr {assert_nil(Mulukhiya.validate_config)}

      # エラーの警告は出ている＝検証は走った。
      assert_match(/config validation: /, captured)
      # ⚠ 黙って false に倒さない。倒したことが観測できる。
      assert_match(/strict flag unreadable/, captured)
    end

    # 検証そのものが実行できない場合だけは握る（schema を読めない環境でも起動する）。
    def test_unreadable_errors_are_skipped
      Config.instance.define_singleton_method(:errors) {raise 'schema unreadable'}
      config[STRICT_KEY] = true

      captured = capture_stderr {assert_nil(Mulukhiya.validate_config)}

      assert_match(/config validation skipped: schema unreadable/, captured)
    end

    # エラーが無ければ strict でも何も起きない。
    def test_strict_is_silent_without_errors
      stub_errors([])
      config[STRICT_KEY] = true

      captured = capture_stderr {assert_nil(Mulukhiya.validate_config)}

      assert_equal('', captured)
    end

    private

    def stub_errors(value)
      Config.instance.define_singleton_method(:errors) {value}
    end

    def restore_errors
      return unless Config.instance.singleton_methods.include?(:errors)
      Config.instance.singleton_class.remove_method(:errors)
    end

    # `warn` は $stderr へ出るので、素で走らせるとテスト出力が汚れる。
    # 出力そのものが仕様（黙って倒さない）なので、捨てずに掴んで検証に使う。
    def capture_stderr
      original = $stderr
      $stderr = StringIO.new
      yield
      return $stderr.string
    ensure
      $stderr = original
    end
  end
end
