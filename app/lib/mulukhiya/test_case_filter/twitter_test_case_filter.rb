module Mulukhiya
  class TwitterTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.twitter.nil?
    end
  end
end
