module Mulukhiya
  class AnnictTestCaseFilter < TestCaseFilter
    def active?
      return account.annict.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
