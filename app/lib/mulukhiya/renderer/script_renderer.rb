module Mulukhiya
  class ScriptRenderer < Ginseng::Web::Renderer
    include Package
    attr_reader :file

    def file=(name)
      @file = name.sub(/\.js$/, '')
      raise Ginseng::RenderError, "Script '#{name}' not found." unless File.exist?(path)
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
