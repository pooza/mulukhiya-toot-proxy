module Mulukhiya
  class StatusTagContract < Contract
    params do
      required(:id).value(:string)
      required(:tag).value(:string)
    end

    rule(:tag) do
      key.failure('タグが正しくありません。') if value.to_hashtag_base.empty?
    end
  end
end
