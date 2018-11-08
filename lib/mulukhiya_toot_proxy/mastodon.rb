require 'httparty'
require 'addressable/uri'
require 'rest-client'
require 'digest/sha1'
require 'json'

module MulukhiyaTootProxy
  class Mastodon
    def initialize(uri, token)
      @uri = Addressable::URI.parse(uri)
      @token = token
    end

    def toot(body)
      return HTTParty.post(create_uri('/api/v1/statuses'), {
        body: body.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => Package.user_agent,
          'Authorization' => "Bearer #{@token}",
          'X-Mulukhiya' => Package.full_name,
        },
        ssl_ca_file: ENV['SSL_CERT_FILE'],
      })
    end

    def upload(path)
      response = RestClient.post(
        create_uri('/api/v1/media').to_s,
        {file: File.new(path, 'rb')},
        {
          'User-Agent' => Package.user_agent,
          'Authorization' => "Bearer #{@token}",
        },
      )
      return JSON.parse(response.body)['id'].to_i
    end

    def upload_remote_resource(uri)
      path = File.join(ROOT_DIR, 'tmp/media', Digest::SHA1.hexdigest(uri))
      File.write(path, fetch(uri))
      return upload(path)
    ensure
      File.unlink(path) if File.exist?(path)
    end

    def self.create_tag(word)
      return '#' + word.gsub(/[^[:alnum:]]+/, '_').sub(/^_/, '').sub(/_$/, '')
    end

    private

    def fetch(uri)
      return HTTParty.get(uri, {
        headers: {
          'User-Agent' => Package.user_agent,
        },
        ssl_ca_file: ENV['SSL_CERT_FILE'],
      })
    rescue => e
      raise ExternalServiceError, "外部ファイルが取得できません。 (#{e.message})"
    end

    def create_uri(href)
      uri = @uri.clone
      uri.path = href
      return uri
    end
  end
end
