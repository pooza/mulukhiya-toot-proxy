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
    # APIController は /mulukhiya/api 配下にマウントされるため、ルート相対の
    # '/program.ics' ではなくフルパスを渡す (feed.slim の購読リンクと同じ規約)。
    def self.uri
      return sns_class.new.create_uri('/mulukhiya/api/program.ics')
    end
  end
end
