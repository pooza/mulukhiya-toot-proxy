module Mulukhiya
  class MeisskeyTestCaseFilter < TestCaseFilter
    def active?
      return Environment.parser_name != 'toot'
    end
  end
end
