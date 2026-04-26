module Mulukhiya
  class ProgramEntryContractTest < TestCase
    def setup
      @contract = ProgramEntryContract.new
      @valid = {
        series: 'テスト作品',
        air: '2026-04-26T20:00:00+09:00',
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
        subtitle: 'サブタイトル',
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

    def test_missing_air
      errors = @contract.call(@valid.except(:air)).errors

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
  end
end
