module Mulukhiya
  class HTTP < Ginseng::Web::HTTP
    include Package

    def mkcol(uri, options = {})
      cnt ||= 0
      options[:headers] = create_headers(options[:headers])
      options[:body] = create_body(options[:body], options[:headers])
      start = Time.now
      uri = create_uri(uri)
      response = RestClient::Request.execute(
        method: :mkcol,
        url: uri.normalize.to_s,
        headers: options[:headers],
      )
      log(method: :mkcol, url: uri, status: response.code, start:)
      raise Ginseng::GatewayError, "Bad response #{response.code}" unless response.code < 400
      return response
    rescue => e
      cnt += 1
      @logger.error(error: e, method: :put, url: uri.to_s, count: cnt)
      raise Ginseng::GatewayError, e.message, e.backtrace unless cnt < retry_limit
      sleep(retry_seconds)
      retry
    end
  end
end
