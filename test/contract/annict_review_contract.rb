module Mulukhiya
  class AnnictReviewContractTest < TestCase
    def setup
      @contract = AnnictReviewContract.new
    end

    def test_minimum_valid_payload
      errors = @contract.call(work_id: 42, body: '本文').errors

      assert_empty(errors)
    end

    def test_full_valid_payload
      errors = @contract.call(
        work_id: 42,
        body: '作品全体の感想',
        rating_overall_state: 'GREAT',
        rating_animation_state: 'GOOD',
        rating_music_state: 'AVERAGE',
        rating_story_state: 'BAD',
        rating_character_state: 'GREAT',
        share_twitter: true,
      ).errors

      assert_empty(errors)
    end

    def test_work_id_required
      errors = @contract.call(body: '本文').errors

      assert_false(errors.empty?)
    end

    def test_body_required
      errors = @contract.call(work_id: 42).errors

      assert_false(errors.empty?)
    end

    def test_body_must_be_filled
      errors = @contract.call(work_id: 42, body: '').errors

      assert_false(errors.empty?)
    end

    def test_work_id_must_be_integer
      errors = @contract.call(work_id: 'abc', body: '本文').errors

      assert_false(errors.empty?)
    end

    def test_work_id_must_be_positive
      errors = @contract.call(work_id: 0, body: '本文').errors

      assert_false(errors.empty?)
    end

    def test_rating_state_must_be_known_enum
      errors = @contract.call(work_id: 42, body: '本文', rating_overall_state: 'AWESOME').errors

      assert_false(errors.empty?)
    end

    def test_each_rating_field_accepts_known_values
      AnnictReviewContract::RATING_FIELDS.each do |field|
        AnnictReviewContract::RATING_STATES.each do |state|
          errors = @contract.call(work_id: 42, body: '本文', field => state).errors

          assert_empty(errors, "expected #{field}=#{state} to be valid")
        end
      end
    end

    def test_long_body_is_accepted
      errors = @contract.call(work_id: 42, body: 'a' * 10_000).errors

      assert_empty(errors)
    end
  end
end
