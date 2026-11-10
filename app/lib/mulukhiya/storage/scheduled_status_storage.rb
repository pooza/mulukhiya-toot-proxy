module Mulukhiya
  class ScheduledStatusStorage < JSONStorage
    def symbolize_names?
      return true
    end

    def prefix
      return 'scheduled_status'
    end
  end
end
