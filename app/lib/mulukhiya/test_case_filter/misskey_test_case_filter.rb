module Mulukhiya
  class MisskeyTestCaseFilter < TestCaseFilter
    def active?
      return Environment.misskey?
    end
  end
end
