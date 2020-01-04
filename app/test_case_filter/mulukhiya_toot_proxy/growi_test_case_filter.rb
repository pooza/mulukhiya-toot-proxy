module MulukhiyaTootProxy
  class GrowiTestCaseFilter < TestCaseFilter
    def active?
      return Environment.test_account.growi.present?
    end
  end
end
