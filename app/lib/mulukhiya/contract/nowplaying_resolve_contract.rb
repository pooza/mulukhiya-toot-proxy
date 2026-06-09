module Mulukhiya
  class NowplayingResolveContract < Contract
    MAX_TEXT_SIZE = 200

    params do
      required(:title).filled(:string, max_size?: MAX_TEXT_SIZE)
      optional(:artist).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:album).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:source_app_name).maybe(:string, max_size?: MAX_TEXT_SIZE)
      optional(:prefer).maybe(:string, max_size?: MAX_TEXT_SIZE)
    end
  end
end
