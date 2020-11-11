module Mulukhiya
  class ScriptRenderer < Ginseng::Web::Renderer
    include Package
    attr_reader :file

    def file=(name)
      @file = name.sub(/\.js$/, '')
      if File.exist?(path)
        @status = 200
      else
        @status = 404
      end
    end

    def path
      return File.join(Environment.dir, 'public/mulukhiya/script', "#{file}.js")
    end

    def type
      return 'text/javascript'
    end

    def to_s
      return File.exist?(path) ? File.read(path) : ''
    end
  end
end
