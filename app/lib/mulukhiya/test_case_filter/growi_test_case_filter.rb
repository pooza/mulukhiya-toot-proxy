module Mulukhiya
  class GrowiTestCaseFilter < TestCaseFilter
    def active?
      return account.growi.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
