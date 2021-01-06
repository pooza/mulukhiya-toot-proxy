module Mulukhiya
  class GrowiTestCaseFilter < TestCaseFilter
    def active?
      return account.growi.nil?
    rescue
      return true
    end
  end
end
