module Mulukhiya
  class NodeinfoController < Controller
    get '/:version' do
      @renderer.message = sns.info
      return @renderer.to_s
    end
  end
end
