module Mulukhiya
  class AnnictTestCaseFilter < TestCaseFilter
    def active?
      return true unless account.annict
      return false
    rescue
      return true
    end
  end
end
