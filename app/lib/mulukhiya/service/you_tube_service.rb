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
      response = @http.get(uri)
      return nil unless response['items'].present?
      return response['items'].first
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
