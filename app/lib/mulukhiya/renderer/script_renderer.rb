module Mulukhiya
  class ScriptRenderer < Ginseng::Web::ScriptRenderer
    include Package
    attr_reader :name

    def dir
      return File.join(environment_class.dir, 'public/mulukhiya/script')
    end

    def to_s
      return compressor.compile(File.read(path)) if minimize?
      return File.read(path)
    end

    def compressor
      @compressor ||= Uglifier.new(harmony: true)
      return @compressor
    end

    def minimize?
      return config['/webui/javascript/minimize']
    end
  end
end
