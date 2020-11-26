module Mulukhiya
  class TagSearchContract < Contract
    params do
      required(:q).value(:string)
    end
  end
end
