module Mulukhiya
  class LemmyTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.lemmy?
      return true if account.lemmy.nil?
      return false
    rescue
      return true
    end
  end
end
