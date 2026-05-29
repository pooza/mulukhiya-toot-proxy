module Mulukhiya
  class ProgramCalendarRenderer < Ginseng::Web::Renderer
    include Package

    def type
      return 'text/calendar; charset=UTF-8'
    end

    def to_s
      return ProgramCalendar.new.to_ics
    end
  end
end
