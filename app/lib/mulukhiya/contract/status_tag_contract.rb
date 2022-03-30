module Mulukhiya
  class StatusTagContract < Contract
    params do
      required(:id).value(:string)
      required(:tag).value(:string)
    end
  end
end
