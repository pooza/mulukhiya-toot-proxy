module Mulukhiya
  class AnnictRecordContract < Contract
    RATING_STATES = ['GREAT', 'GOOD', 'AVERAGE', 'BAD'].freeze

    params do
      required(:episode_id).value(:integer, gt?: 0)
      optional(:comment).maybe(:string)
      optional(:rating_state).maybe(:string)
    end

    rule(:rating_state) do
      next unless value.is_a?(String)
      unless RATING_STATES.include?(value)
        key.failure("#{RATING_STATES.join(' / ')} のいずれかを指定してください。")
      end
    end
  end
end
