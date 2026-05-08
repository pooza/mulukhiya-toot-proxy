module Mulukhiya
  class AnnictRecordContractTest < TestCase
    def setup
      @contract = AnnictRecordContract.new
    end

    def test_minimum_valid_payload
      errors = @contract.call(episode_id: 42).errors

      assert_empty(errors)
    end

    def test_full_valid_payload
      errors = @contract.call(
        episode_id: 42,
        comment: '本日の感想',
        rating_state: 'GREAT',
      ).errors

      assert_empty(errors)
    end

    def test_episode_id_required
      errors = @contract.call(comment: 'X').errors

      assert_false(errors.empty?)
    end

    def test_episode_id_must_be_integer
      errors = @contract.call(episode_id: 'abc').errors

      assert_false(errors.empty?)
    end

    def test_episode_id_must_be_positive
      errors = @contract.call(episode_id: 0).errors

      assert_false(errors.empty?)
    end

    def test_rating_state_must_be_known_enum
      errors = @contract.call(episode_id: 42, rating_state: 'AWESOME').errors

      assert_false(errors.empty?)
    end

    def test_rating_state_accepts_each_known_value
      AnnictRecordContract::RATING_STATES.each do |state|
        errors = @contract.call(episode_id: 42, rating_state: state).errors

        assert_empty(errors, "expected #{state} to be valid")
      end
    end

    def test_long_comment_is_accepted
      errors = @contract.call(episode_id: 42, comment: 'a' * 10_000).errors

      assert_empty(errors)
    end

    def test_nullable_optional_fields
      errors = @contract.call(episode_id: 42, comment: nil, rating_state: nil).errors

      assert_empty(errors)
    end
  end
end
