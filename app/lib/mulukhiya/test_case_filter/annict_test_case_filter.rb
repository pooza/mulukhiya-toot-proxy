module Mulukhiya
  class AnnictTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.annict.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
