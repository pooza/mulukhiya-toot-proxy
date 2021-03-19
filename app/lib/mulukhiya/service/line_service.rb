module Mulukhiya
  class LineService < Ginseng::LineService
    include Package

    def initialize(params = {})
      super
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
