module Mulukhiya
  class ProgramEntryUpdateContractTest < TestCase
    def setup
      @contract = ProgramEntryUpdateContract.new
    end

    def test_empty_payload_is_valid
      errors = @contract.call({}).errors

      assert_empty(errors)
    end

    def test_partial_episode_only
      errors = @contract.call(episode: 12).errors

      assert_empty(errors)
    end

    def test_partial_subtitle_only
      errors = @contract.call(subtitle: 'サブタイトル').errors

      assert_empty(errors)
    end

    def test_series_when_provided_must_not_be_empty
      errors = @contract.call(series: '').errors

      assert_false(errors.empty?)
    end

    def test_series_when_provided_must_not_be_nil
      errors = @contract.call(series: nil).errors

      assert_false(errors.empty?)
    end

    def test_series_when_provided_with_value_passes
      errors = @contract.call(series: 'テスト作品').errors

      assert_empty(errors)
    end

    def test_clearable_optionals_accept_nil
      errors = @contract.call(
        minutes: nil,
        episode: nil,
        episode_suffix: nil,
        subtitle: nil,
        extra_tags: nil,
        annict_work_id: nil,
        annict_episode_id: nil,
        source_type: nil,
        source_url: nil,
      ).errors

      assert_empty(errors)
    end

    def test_episode_must_be_integer
      errors = @contract.call(episode: 'not-a-number').errors

      assert_false(errors.empty?)
    end

    def test_series_max_length
      errors = @contract.call(series: 'a' * 201).errors

      assert_false(errors.empty?)
    end

    def test_subtitle_max_length
      errors = @contract.call(subtitle: 'a' * 201).errors

      assert_false(errors.empty?)
    end

    def test_extra_tags_max_count
      errors = @contract.call(extra_tags: Array.new(33, 'tag')).errors

      assert_false(errors.empty?)
    end

    def test_legacy_key_passes_for_update
      # PUT は URL :key (route 識別子) で既存エントリを指す。Code path 上は
      # body の :key は controller 側で除外されるが、Sinatra の params は
      # URL :key を含むため contract も通過させる必要がある。
      errors = @contract.call(key: 'legacy/key with spaces and$pecial:chars', episode: 5).errors

      assert_empty(errors)
    end

    def test_legacy_long_key_passes_for_update
      errors = @contract.call(key: 'a' * 200, episode: 5).errors

      assert_empty(errors)
    end

    def test_source_url_rejects_non_http_scheme
      errors = @contract.call(source_url: 'javascript:alert(1)').errors

      assert_false(errors.empty?)
    end

    def test_source_url_accepts_http_and_https
      assert_empty(@contract.call(source_url: 'http://example.com/').errors)
      assert_empty(@contract.call(source_url: 'https://example.com/').errors)
    end

    def test_error_messages_include_field_name
      assert_match(/シリーズ名/, @contract.exec(series: '').fetch(:series).join)
      assert_match(
        /追加タグ/,
        @contract.exec(extra_tags: ['a' * (ProgramEntryContract::MAX_TAG_SIZE + 1)])
          .fetch(:extra_tags).join,
      )
      assert_match(
        /ソース URL/,
        @contract.exec(source_url: 'javascript:alert(1)').fetch(:source_url).join,
      )
    end
  end
end
