module MulukhiyaTootProxy
  class HTTP < Ginseng::HTTP
    include Package

    def upload(uri, file, headers = {}, body = {})
      file = File.new(file, 'rb') unless file.is_a?(File)
      uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
      headers['User-Agent'] ||= user_agent
      body[:file] = file
      return RestClient.post(uri.normalize.to_s, body, headers)
    end
  end
end
