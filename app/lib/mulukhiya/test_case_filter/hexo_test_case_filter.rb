module Mulukhiya
  class HexoTestCaseFilter < TestCaseFilter
    def active?
      config['/handler/hexo_announce/category']
      config['/handler/hexo_announce/path']
      return false
    rescue
      return true
    end
  end
end
