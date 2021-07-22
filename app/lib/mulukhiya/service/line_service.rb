module Mulukhiya
  class LineService < Ginseng::LineService
    include Package

    def initialize(params = {})
      super rescue nil
      @id = params[:id] || LineService.id
      @token = params[:token] || LineService.token
      @token = (@token.decrypt rescue @token)
    end

    def self.id
      return config['/alert/line/to'] rescue nil
    end

    def self.token
      return config['/alert/line/token'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/alert/line/token']
    end

    def self.config?
      return false unless LineService.id
      return false unless LineService.token
      return true
    end
  end
end
