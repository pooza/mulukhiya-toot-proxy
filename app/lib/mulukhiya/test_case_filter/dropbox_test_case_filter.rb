module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.dropbox.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
