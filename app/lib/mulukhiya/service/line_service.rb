module Mulukhiya
  class LineService < Ginseng::LineService
    include Package

    def initialize(params = {})
      super rescue nil
      @id = params[:id] || LineService.id
      @token = (params[:token].decrypt rescue params[:token]) || LineService.token
    end

    def self.id
      return Handler.create('line_alert').id
    end

    def self.token
      return Handler.create('line_alert').token
    end

    def self.config?
      return false unless id
      return false unless token
      return true
    end
  end
end
