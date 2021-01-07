module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return account.dropbox.nil? rescue true
    end
  end
end
