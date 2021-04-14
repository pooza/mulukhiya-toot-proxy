module Mulukhiya
  class NoteTestCaseFilter < TestCaseFilter
    def active?
      return Environment.parser_name != 'note'
    end
  end
end
