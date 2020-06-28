module Mulukhiya
  class MisskeyAuthContract < Contract
    params do
      required(:token).value(:string)
    end
  end
end
