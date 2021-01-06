module Mulukhiya
  class HexoTestCaseFilter < TestCaseFilter
    def active?
      config['/handler/hexo_announcement/category']
      config['/handler/hexo_announcement/path']
      return false
    rescue
      return true
    end
  end
end
