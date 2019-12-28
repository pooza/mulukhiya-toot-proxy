module MulukhiyaTootProxy
  class DolphinTestCaseFilter < TestCaseFilter
    def active?
      return Environment.dolphin?
    end
  end
end
