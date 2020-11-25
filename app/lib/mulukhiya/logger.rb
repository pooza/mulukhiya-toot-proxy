module Mulukhiya
  class Logger < Ginseng::Logger
    include Package

    def create_message(src)
      if src.is_a?(Hash) && src[:error].is_a?(StandardError)
        error = Ginseng::Error.create(src[:error])
        file, line = error.backtrace.first.split(':')
        src[:error] = {
          message: error.message,
          file: file.sub("#{Environment.dir}/", ''),
          line: line.to_i,
        }
      end
      return super
    end
  end
end
