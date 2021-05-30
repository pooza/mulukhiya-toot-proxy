module Mulukhiya
  class AnnouncementTestCaseFilter < TestCaseFilter
    def active?
      return !controller_class.announcement?
    end
  end
end
