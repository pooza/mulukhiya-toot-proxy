module Mulukhiya
  class RawRenderer < Ginseng::Web::Renderer
    attr_accessor :type, :body

    alias to_s body
  end
end
