module Mulukhiya
  class HTTP < Ginseng::Web::HTTP
    include Package

    def put(uri, options = {})
      cnt ||= 0
      options[:headers] = create_headers(options[:headers])
      options[:body] = create_body(options[:body], options[:headers])
      uri = create_uri(uri)
      start = Time.now
      response = HTTParty.put(uri.normalize, options)
      log(method: :put, url: uri, status: response.code, start: start)
      raise GatewayError, "Bad response #{response.code}" unless response.code < 400
      return response
    rescue => e
      cnt += 1
      @logger.error(error: e, method: :put, url: uri.to_s, count: cnt)
      raise GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(retry_seconds)
      retry
    end
  end
end
