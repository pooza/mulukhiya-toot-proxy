module Mulukhiya
  class AnnictTestCaseFilter < TestCaseFilter
    def active?
      return account.annict.nil? rescue true
    end
  end
end
