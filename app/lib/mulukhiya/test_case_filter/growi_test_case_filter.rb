module Mulukhiya
  class GrowiTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.growi?
      return true if account.growi.nil?
      return false
    rescue
      return true
    end
  end
end
