module Mulukhiya
  class NodeinfoController < Controller
    get '/:version' do
      @renderer.message = sns.nodeinfo.merge(mulukhiya: config.about)
      return @renderer.to_s
    end
  end
end
