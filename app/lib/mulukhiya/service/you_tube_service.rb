module Mulukhiya
  class YouTubeService < Ginseng::YouTube::Service
    include Package

    def lookup_video(id)
      uri = @http.create_uri('/youtube/v3/videos')
      uri.query_values = {
        'part' => 'snippet,statistics',
        'key' => api_key,
        'id' => id,
      }
      r = @http.get(uri)
      raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
      return nil unless r['items'].present?
      return r['items'].first
    rescue => e
      raise Ginseng::GatewayError, "invalid video '#{id}' (#{e.message})"
    end

    def self.config?
      config = Config.instance
      config['/google/api/key']
      return true
    rescue Ginseng::ConfigError
      return false
    end
  end
end
