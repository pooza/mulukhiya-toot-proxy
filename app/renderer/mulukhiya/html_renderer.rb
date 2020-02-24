module Mulukhiya
  class HTMLRenderer < Ginseng::Web::HTMLRenderer
    include Package
  end

  def render(template)
    renderer = HTMLRenderer.new
    renderer.template = template
    return renderer.to_s
  end
end
