module Mulukhiya
  class ProgressBar < ProgressBar::Base
    include Package

    def self.create(params = {})
      return nil if Environment.test?
      return nil unless Environment.rake?
      params[:format] ||= config['/cli/progress_bar/format']
      return new(params)
    end
  end
end
