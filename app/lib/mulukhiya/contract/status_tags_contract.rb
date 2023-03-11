module Mulukhiya
  class StatusTagsContract < Contract
    params do
      required(:id).value(:string)
      required(:tags).each(:string)
    end
  end
end
