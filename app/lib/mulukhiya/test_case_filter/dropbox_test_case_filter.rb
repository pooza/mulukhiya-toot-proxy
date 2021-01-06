module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return account.dropbox.nil?
    rescue
      return true
    end
  end
end
