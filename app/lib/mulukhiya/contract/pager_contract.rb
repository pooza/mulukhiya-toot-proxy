module Mulukhiya
  class PagerContract < Contract
    params do
      optional(:page).value(:integer).value(gt?: 0)
    end
  end
end
