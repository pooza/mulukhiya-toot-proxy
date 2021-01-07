module Mulukhiya
  class GrowiTestCaseFilter < TestCaseFilter
    def active?
      return account.growi.nil? rescue true
    end
  end
end
