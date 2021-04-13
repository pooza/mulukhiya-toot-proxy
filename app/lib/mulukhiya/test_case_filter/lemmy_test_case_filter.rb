module Mulukhiya
  class LemmyTestCaseFilter < TestCaseFilter
    def active?
      return account.lemmy.nil? rescue true
    end
  end
end
