module Mulukhiya
  class NodeinfoController < Controller
    get '/:version' do
      response = sns.http.get('/nodeinfo/2.0.json', {
        headers: {'X-Mulukhiya' => Package.full_name},
      })
      @renderer.message = response.parsed_response.merge(mulukhiya: config.about)
      return @renderer.to_s
    end
  end
end
