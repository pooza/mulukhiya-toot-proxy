module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return !Environment.test_account.dropbox.present?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
