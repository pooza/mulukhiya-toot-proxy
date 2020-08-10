module Mulukhiya
  class AnnictAuthContract < Contract
    params do
      required(:token).value(:string)
      required(:code).value(:string)
    end
  end
end
