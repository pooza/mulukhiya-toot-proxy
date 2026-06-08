module Mulukhiya
  class WordSuggestContract < Contract
    params do
      required(:q).value(:string)
      optional(:limit)
    end
  end
end
