module Mulukhiya
  class NodeinfoController < Controller
    get '/nodeinfo/:version' do
      @renderer.message = config.about
      return @renderer.to_s
    end
  end
end
