module Mulukhiya
  class AnnictReviewContract < Contract
    RATING_STATES = ['GREAT', 'GOOD', 'AVERAGE', 'BAD'].freeze
    RATING_FIELDS = [
      :rating_overall_state,
      :rating_animation_state,
      :rating_music_state,
      :rating_story_state,
      :rating_character_state,
    ].freeze

    params do
      required(:work_id).value(:integer, gt?: 0)
      required(:body).filled(:string)
      optional(:rating_overall_state).maybe(:string)
      optional(:rating_animation_state).maybe(:string)
      optional(:rating_music_state).maybe(:string)
      optional(:rating_story_state).maybe(:string)
      optional(:rating_character_state).maybe(:string)
      optional(:share_twitter).maybe(:bool)
      optional(:share_facebook).maybe(:bool)
    end

    RATING_FIELDS.each do |field|
      rule(field) do
        next unless value.is_a?(String)
        unless RATING_STATES.include?(value)
          key.failure("#{RATING_STATES.join(' / ')} のいずれかを指定してください。")
        end
      end
    end
  end
end
