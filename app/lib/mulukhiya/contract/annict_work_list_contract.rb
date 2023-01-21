module Mulukhiya
  class AnnictWorkListContract < Contract
    params do
      optional(:q).value(:string)
    end
  end
end
