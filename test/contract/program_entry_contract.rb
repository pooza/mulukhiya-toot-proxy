module Mulukhiya
  class ProgramEntryContractTest < TestCase
    def setup
      @contract = ProgramEntryContract.new
      @valid = {
        series: 'テスト作品',
      }
    end

    def test_valid_minimum
      errors = @contract.call(@valid).errors

      assert_empty(errors)
    end

    def test_valid_full
      errors = @contract.call(@valid.merge(
        key: 'test',
        episode: 12,
        episode_suffix: '話',
        minutes: 30,
        start_time: '21:00',
        subtitle: 'サブタイトル',
        air: false,
        livecure: true,
        enable: true,
        extra_tags: ['tag1', 'tag2'],
        annict_work_id: 1234,
        annict_episode_id: 5678,
        source_type: 'annict',
        source_url: 'https://annict.com/works/1234',
      )).errors

      assert_empty(errors)
    end

    def test_missing_series
      errors = @contract.call(@valid.except(:series)).errors

      assert_false(errors.empty?)
    end

    def test_empty_series
      errors = @contract.call(@valid.merge(series: '')).errors

      assert_false(errors.empty?)
    end

    def test_episode_must_be_integer
      errors = @contract.call(@valid.merge(episode: 'not-a-number')).errors

      assert_false(errors.empty?)
    end

    def test_air_must_be_bool
      errors = @contract.call(@valid.merge(air: 'string')).errors

      assert_false(errors.empty?)
    end

    def test_clearable_optionals_accept_nil
      errors = @contract.call(@valid.merge(
        minutes: nil,
        start_time: nil,
        episode: nil,
        episode_suffix: nil,
        subtitle: nil,
        extra_tags: nil,
        annict_work_id: nil,
        annict_episode_id: nil,
        source_type: nil,
        source_url: nil,
      )).errors

      assert_empty(errors)
    end

    def test_params_keys_match_schema_definition
      schema_keys = ProgramEntryContract.schema.key_map.map(&:name).to_set(&:to_sym)

      assert_equal(schema_keys, ProgramEntryContract::PARAMS_KEYS.to_set)
    end

    def test_writable_keys_excludes_key
      assert_equal(
        (ProgramEntryContract::PARAMS_KEYS - [:key]).to_set,
        ProgramEntryContract::WRITABLE_KEYS.to_set,
      )
      assert_false(ProgramEntryContract::WRITABLE_KEYS.include?(:key))
    end

    def test_error_messages_include_field_name
      assert_match(/シリーズ名/, @contract.exec(@valid.merge(series: '')).fetch(:series).join)
      assert_match(/キー/, @contract.exec(@valid.merge(key: 'bad key!')).fetch(:key).join)
      assert_match(
        /追加タグ/,
        @contract.exec(@valid.merge(extra_tags: ['a' * (ProgramEntryContract::MAX_TAG_SIZE + 1)]))
          .fetch(:extra_tags).join,
      )
      assert_match(
        /ソース URL/,
        @contract.exec(@valid.merge(source_url: 'javascript:alert(1)')).fetch(:source_url).join,
      )
    end

    def test_series_max_length
      errors = @contract.call(@valid.merge(series: 'a' * 201)).errors

      assert_false(errors.empty?)
    end

    def test_subtitle_max_length
      errors = @contract.call(@valid.merge(subtitle: 'a' * 201)).errors

      assert_false(errors.empty?)
    end

    def test_start_time_accepts_valid_formats
      ['0:00', '09:05', '9:05', '21:00', '23:59'].each do |time|
        assert_empty(@contract.call(@valid.merge(start_time: time)).errors, time)
      end
    end

    def test_start_time_accepts_empty_and_nil_as_unset
      assert_empty(@contract.call(@valid.merge(start_time: '')).errors)
      assert_empty(@contract.call(@valid.merge(start_time: nil)).errors)
    end

    def test_start_time_rejects_invalid_formats
      ['24:00', '12:60', '9', '9:5', 'morning', '21:00:00'].each do |time|
        assert_false(@contract.call(@valid.merge(start_time: time)).errors.empty?, time)
      end
    end

    def test_start_time_error_message_includes_field_name
      assert_match(
        /開始時刻/,
        @contract.exec(@valid.merge(start_time: '24:99')).fetch(:start_time).join,
      )
    end

    def test_key_format_rejects_invalid_chars
      errors = @contract.call(@valid.merge(key: 'invalid key!')).errors

      assert_false(errors.empty?)
    end

    def test_key_format_accepts_alphanumeric
      errors = @contract.call(@valid.merge(key: 'abc-123_XYZ')).errors

      assert_empty(errors)
    end

    def test_key_max_length
      errors = @contract.call(@valid.merge(key: 'a' * 65)).errors

      assert_false(errors.empty?)
    end

    def test_extra_tags_max_count
      errors = @contract.call(@valid.merge(extra_tags: Array.new(33, 'tag'))).errors

      assert_false(errors.empty?)
    end

    def test_extra_tags_element_max_length
      errors = @contract.call(@valid.merge(extra_tags: ['a' * 65])).errors

      assert_false(errors.empty?)
    end

    def test_source_url_rejects_non_http_scheme
      errors = @contract.call(@valid.merge(source_url: 'javascript:alert(1)')).errors

      assert_false(errors.empty?)
    end

    def test_source_url_accepts_http_and_https
      assert_empty(@contract.call(@valid.merge(source_url: 'http://example.com/')).errors)
      assert_empty(@contract.call(@valid.merge(source_url: 'https://example.com/')).errors)
    end
  end
end
