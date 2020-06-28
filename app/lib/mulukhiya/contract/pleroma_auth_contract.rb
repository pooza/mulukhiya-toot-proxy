module Mulukhiya
  class PleromaAuthContract < Contract
    params do
      required(:code).value(:string)
    end
  end
end
