module MulukhiyaTootProxy
  class DropboxTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.dropbox.present?
    end
  end
end
