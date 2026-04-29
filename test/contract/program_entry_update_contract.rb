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
  end
end
