module Mulukhiya
  class StaticMediaRenderer < Ginseng::Web::Renderer
    include Package
    attr_reader :name

    def name=(name)
      @name = name
      raise Ginseng::RenderError, "Media file '#{name}' not found." unless File.exist?(path)
    end

    def path
      return File.join(Environment.dir, 'public/mulukhiya/media', name)
    end

    def type
      return MediaFile.new(path).type if File.exist?(path)
    end

    def to_s
      return File.exist?(path) ? File.read(path) : ''
    end
  end
end
