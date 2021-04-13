module Mulukhiya
  class TootTestCaseFilter < TestCaseFilter
    def active?
      return Environment.parser_name != 'toot'
    end
  end
end
