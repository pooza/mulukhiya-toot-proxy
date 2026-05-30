module Mulukhiya
  class ProgramCalendarRenderer < Ginseng::Web::Renderer
    include Package
    include SNSMethods

    def type
      return 'text/calendar; charset=UTF-8'
    end

    def to_s
      return ProgramCalendar.new.to_ics
    end

    # 番組表エディタ画面に購読リンクとして表示する公開 .ics の絶対 URI。
    def self.uri
      return sns_class.new.create_uri('/program.ics')
    end
  end
end
