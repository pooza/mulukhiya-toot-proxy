module Mulukhiya
  class MastodonAuthContract < Contract
    params do
      required(:code).value(:string)
    end
  end
end
