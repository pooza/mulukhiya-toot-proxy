module MulukhiyaTootProxy
  class CiTestCaseFilter < TestCaseFilter
    def active?
      return Environment.ci?
    end
  end
end
