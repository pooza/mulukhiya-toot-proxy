module Mulukhiya
  class TwitterAuthContract < Contract
    params do
      required(:token).value(:string)
      required(:oauth_token).value(:string)
      required(:oauth_verifier).value(:string)
    end
  end
end
