require 'httparty'
require 'addressable/uri'
require 'mulukhiya/package'
require 'rest-client'
require 'json'

module MulukhiyaTootProxy
  class Mastodon
    def initialize(url, token)
      @url = Addressable::URI.parse(url)
      @token = token
    end

    def toot(body)
      return HTTParty.post(create_url('/api/v1/statuses'), {
        body: body.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => Package.user_agent,
          'Authorization' => "Bearer #{@token}",
          'X-Mulukhiya' => '1',
        },
      })
    end

    def upload(path)
      response = RestClient.post(
        create_url('/api/v1/media').to_s,
        {file: File.new(path, 'rb')},
        {
          'User-Agent' => Package.user_agent,
          'Authorization' => "Bearer #{@token}",
        },
      )
      return JSON.parse(response.body)['id'].to_i
    end

    def upload_remote_resource(url)
      path = File.join(ROOT_DIR, 'tmp/media', Digest::SHA1.hexdigest(url))
      File.write(path, HTTParty.get(url))
      return upload(path)
    ensure
      File.unlink(path) if File.exist?(path)
    end

    private

    def create_url(href)
      toot_url = @url.clone
      toot_url.path = href
      return toot_url
    end
  end
end
