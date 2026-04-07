module Mulukhiya
  class ScheduledStatusTagsContract < Contract
    params do
      required(:tags).each(:string)
    end
  end
end
