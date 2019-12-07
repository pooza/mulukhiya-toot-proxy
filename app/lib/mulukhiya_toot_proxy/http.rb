module MulukhiyaTootProxy
  class HTTP < Ginseng::HTTP
    include Package

    def delete(uri, options = {})
      options[:headers] ||= {}
      options[:headers]['User-Agent'] ||= user_agent
      options[:headers]['Content-Type'] ||= 'application/json'
      uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
      return HTTParty.delete(uri.normalize, options)
    end
  end
end
