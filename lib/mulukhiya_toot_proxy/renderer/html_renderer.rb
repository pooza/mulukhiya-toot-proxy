module MulukhiyaTootProxy
  class HTMLRenderer < Ginseng::Renderer
    def template=(name)
      @template = Template.new("#{name}.html")
    end

    def []=(key, value)
      @template[key] = value
    end

    def type
      return 'text/html; charset=UTF-8'
    end

    def to_s
      return @template.to_s
    end
  end
end
