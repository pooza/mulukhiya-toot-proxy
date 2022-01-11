module Mulukhiya
  class ClippingWorker < Worker
    sidekiq_options retry: 3

    def federate?
      return true if Environment.test?
      return worker_config(:federate)
    end

    def perform(params)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_body(params)
      params.deep_symbolize_keys!
      uri = create_status_uri(params[:uri])
      raise Ginseng::RequestError, "Invalid URL '#{params[:uri]}'" unless uri&.valid?
      return uri.to_md if uri.public?
      return uri.to_md if uri.local?
      return uri.to_md if federate?
      return uri.to_s
    rescue => e
      e.log(uri: uri.to_s)
      return uri.to_s
    end
  end
end
