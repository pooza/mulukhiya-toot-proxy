module Mulukhiya
  class LineService < Ginseng::LineService
    include Package

    def initialize(params = {})
      @http = http_class.new
      @config = config_class.instance
      @http.base_uri = @config['/line/urls/api']
      @id = params[:id] || @config['/alert/line/to']
      @token = params[:token] || @config['/alert/line/token']
    end

    def self.config?
      return false unless config['/alert/line/token'].present?
      return false unless config['/alert/line/to'].present?
      return true
    rescue Ginseng::ConfigError
      return false
    end
  end
end
