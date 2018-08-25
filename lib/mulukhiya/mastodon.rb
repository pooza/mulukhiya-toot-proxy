require 'httparty'
require 'addressable/uri'
require 'mulukhiya/package'
require 'tempfile'
require 'rest-client'

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

    def upload_remote_image(url)
      file = Tempfile.create(
        Digest::SHA1.hexdigest(url),
        File.join(ROOT_DIR, 'tmp/media'),
      )
      file.write(HTTParty.get(url))

      response = RestClient.post(
        create_url('/api/v1/media').to_s, {
          file: File.new(file.path, 'rb'),
        }, {
          'User-Agent' => Package.user_agent,
          'Authorization' => "Bearer #{@token}",
        }
      )
      return JSON.parse(response.body)['id'].to_i
    ensure
      File.unlink(file.path) if File.exist?(file.path)
    end

    private

    def create_url(href)
      toot_url = @url.clone
      toot_url.path = href
      return toot_url
    end

    def headers
      return
    end
  end
end
