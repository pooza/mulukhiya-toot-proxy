module Mulukhiya
  class HexoTestCaseFilter < TestCaseFilter
    def active?
      @config = Config.instance
      @config['/handler/hexo_announcement/category']
      @config['/handler/hexo_announcement/path']
      return false
    rescue Ginseng::ConfigError
      return true
    end
  end
end
