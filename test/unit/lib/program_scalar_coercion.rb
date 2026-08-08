module Mulukhiya
  # var/program.yaml を手書きしたときのスカラー型の受け (#4373 / #4537)。
  #
  # ⚠ ProgramTest / ProgramFetcherTest は livecure? が false の環境では
  # 丸ごと omit されるため、そちらへ足すと「番組表を持たないサーバーでは
  # 検査されない」状態になる。ここは I/O を持たない純関数だけを見るので、
  # どの環境でも必ず走る。
  class ProgramScalarCoercionTest < TestCase
    def program
      return Program.instance
    end

    def coerce(entry)
      return program.send(:coerce_scalars, entry)
    end

    def load_yaml(source)
      return YAML.safe_load(source, permitted_classes: ProgramFetcher::PERMITTED_YAML_CLASSES)
    end

    # ---- 許可クラス ----
    #
    # 許可していないクラスが 1 つでも出ると Psych::DisallowedClass になり、
    # **そのエントリだけでなく番組表全体が読めなくなる**。

    def test_permits_unquoted_date
      assert_equal(Date.new(2026, 8, 8), load_yaml("next_on: 2026-08-08\n")['next_on'])
    end

    # 時刻まで書くと Date ではなく Time で入る (#4537)。
    def test_permits_unquoted_timestamp
      assert_kind_of(Time, load_yaml("next_on: 2026-08-08 09:00:00\n")['next_on'])
    end

    def test_permitted_classes_match_ginseng_config
      [Date, Time].each do |klass|
        assert_includes(ProgramFetcher::PERMITTED_YAML_CLASSES, klass)
      end
    end

    # ---- 文字列への正規化 ----
    #
    # 以降の層 (contract / エディタ / ProgramCalendar) は常に文字列だけ見ればよい。

    def test_coerces_date_to_string
      assert_equal('2026-08-08', coerce({'next_on' => Date.new(2026, 8, 8)})['next_on'])
    end

    def test_coerces_timestamp_to_string
      entry = load_yaml("next_on: 2026-08-08 09:00:00\n")

      assert_equal('2026-08-08', coerce(entry)['next_on'])
    end

    # ⚠ Psych はゾーン無しの値を UTC として読み、ローカル (JST) の Time を返す。
    # そのまま strftime すると深夜帯の値が翌日へずれる。書いたとおりの日付を拾う。
    def test_coerces_late_night_timestamp_without_shifting_the_date
      entry = load_yaml("next_on: 2026-08-08 23:30:00\n")

      assert_equal('2026-08-08', coerce(entry)['next_on'])
    end

    # 文字列・不正値には触らない。妥当性の判定は contract / ProgramCalendar 側。
    def test_keeps_string_and_invalid_values_untouched
      assert_equal('2026-08-08', coerce({'next_on' => '2026-08-08'})['next_on'])
      assert_equal('not a date', coerce({'next_on' => 'not a date'})['next_on'])
      assert_equal(20_260_808, coerce({'next_on' => 20_260_808})['next_on'])
      assert_nil(coerce({'series' => 'A'})['next_on'])
    end

    # 無クォートの start_time は YAML の 60 進数解釈で Integer になる。
    def test_coerces_sexagesimal_start_time
      assert_equal('20:30', coerce({'start_time' => 73_800})['start_time'])
    end
  end
end
