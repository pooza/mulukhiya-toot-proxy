module Mulukhiya
  class HexoTestCaseFilter < TestCaseFilter
    def active?
      handler = Handler.create('hexo_announce')
      return true unless handler.handler_config(:category)
      return true unless handler.handler_config(:dir)
      return false
    rescue
      return true
    end
  end
end
