module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.dropbox?
      return true unless account.dropbox
      return false
    rescue
      return true
    end
  end
end
