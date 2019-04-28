require 'sass'

module MulukhiyaTootProxy
  class CSSRenderer < Ginseng::Renderer
    def template=(name)
      name.sub!(/\.sass/i, '')
      @template = Sass::Engine.new(
        File.read(File.join(Environment.dir, "views/#{name}.sass")),
      )
    end

    def type
      return 'text/css; charset=UTF-8'
    end

    def to_s
      raise RenderError, 'Template file undefined' unless @template
      return @template.render
    end
  end
end
