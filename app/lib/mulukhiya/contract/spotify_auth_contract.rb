module Mulukhiya
  class SpotifyAuthContract < Contract
    params do
      required(:token).value(:string)
      required(:code).value(:string)
    end
  end
end
