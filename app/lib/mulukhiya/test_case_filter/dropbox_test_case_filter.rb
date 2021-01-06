module Mulukhiya
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return account.dropbox.nil?
    rescue Ginseng::ConfigError
      return true
    end
  end
end
