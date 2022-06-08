module Mulukhiya
  class StatusListContract < Contract
    params do
      optional(:page).value(:integer).value(gt?: 0)
      optional(:q).value(:string)
      optional(:self).value(:integer)
    end
  end
end
