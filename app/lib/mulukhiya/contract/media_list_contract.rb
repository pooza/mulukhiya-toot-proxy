module Mulukhiya
  class MediaListContract < Contract
    params do
      optional(:page).value(:integer).value(gt?: 0)
      optional(:q).value(:string)
      optional(:only_person).value(:integer)
    end
  end
end
