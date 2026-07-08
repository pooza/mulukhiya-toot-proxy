module Mulukhiya
  class ConfigTest < TestCase
    # /founded_on 設定時は ISO 8601 date に正規化して返す (#4434)。
    def test_founded_at_from_config
      config['/founded_on'] = '2021-04-01'

      assert_equal('2021-04-01', config.send(:founded_at))
    end

    def test_founded_at_normalizes_non_iso_input
      config['/founded_on'] = '2021/04/01'

      assert_equal('2021-04-01', config.send(:founded_at))
    end

    # 未設定かつ最古アカウント取得不能（DB 未接続）なら nil に倒す。
    def test_founded_at_nil_when_unset_and_no_db
      config['/founded_on'] = nil

      assert_nil(config.send(:founded_at))
    end

    # 未設定時は account_class の最古アカウント作成日で近似する (#4434)。
    # account_class (Sequel::Model) はクラス定義時に DB 接続を要求するため、
    # DB 未接続 (harness 無し) 環境では omit する。
    def test_founded_at_falls_back_to_oldest_account
      klass = begin
        Environment.account_class
      rescue
        nil
      end
      omit('DB 未接続のため account_class をロードできない') unless klass
      config['/founded_on'] = nil
      original = klass.method(:founded_at)
      klass.define_singleton_method(:founded_at) {Time.new(2019, 5, 1, 12, 34, 56)}
      begin
        assert_equal('2019-05-01', config.send(:founded_at))
      ensure
        klass.define_singleton_method(:founded_at, original)
      end
    end
  end
end
