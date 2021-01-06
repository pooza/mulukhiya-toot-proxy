module Mulukhiya
  class AnnictTestCaseFilter < TestCaseFilter
    def active?
      return account.annict.nil?
    rescue
      return true
    end
  end
end
