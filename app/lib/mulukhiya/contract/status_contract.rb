module Mulukhiya
  class StatusContract < Contract
    params do
      required(:id).value(:string)
    end
  end
end
