module Mulukhiya
  class HTMLRenderer < Ginseng::Web::HTMLRenderer
    include Package
  end
end

def render(template)
  renderer = Mulukhiya::HTMLRenderer.new
  renderer.template = template
  return renderer.to_s
end
