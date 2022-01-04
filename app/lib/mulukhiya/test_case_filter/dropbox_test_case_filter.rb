module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return true unless controller_class.dropbox?
      return true if account.dropbox.nil?
      return false
    rescue
      return true
    end
  end
end
