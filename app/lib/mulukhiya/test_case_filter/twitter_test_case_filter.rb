module Mulukhiya
  class TwitterTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.twitter.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
