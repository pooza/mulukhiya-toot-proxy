module Mulukhiya
  class IsCatContract < Contract
    params do
      required(:accts).value(:array, min_size?: 1).each(:str?)
    end
  end
end
