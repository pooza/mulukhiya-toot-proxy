module Mulukhiya
  class NextcloudTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.nextcloud?
      return true unless account.nextcloud
      return false
    rescue
      return true
    end
  end
end
