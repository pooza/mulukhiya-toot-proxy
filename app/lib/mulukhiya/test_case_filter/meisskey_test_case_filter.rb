module Mulukhiya
  class MeisskeyTestCaseFilter < TestCaseFilter
    def active?
      return Environment.meisskey?
    end
  end
end
