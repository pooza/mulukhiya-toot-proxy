module Mulukhiya
  class ProgressBar < ProgressBar::Base
    include Package

    def self.create(params = {})
      return nil unless Environment.test?
      params[:format] ||= config['/cli/progress_bar/format']
      return ProgressBar.new(params)
    end
  end
end
