module Mulukhiya
  class IsCatContract < Contract
    MAX_ACCTS = 50

    params do
      required(:accts).value(:array, min_size?: 1, max_size?: 50).each(:str?)
    end
  end
end
