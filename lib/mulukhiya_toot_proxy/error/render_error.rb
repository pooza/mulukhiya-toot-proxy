module MulukhiyaTootProxy
  class RenderError < Ginseng::Error
    def status
      return 500
    end
  end
end
