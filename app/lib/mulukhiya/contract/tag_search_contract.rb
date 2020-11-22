module Mulukhiya
  class TagSearchContract < Contract
    params do
      required(:keyword).value(:string)
    end
  end
end
