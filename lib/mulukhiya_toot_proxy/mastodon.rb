require 'httparty'
require 'rest-client'
require 'digest/sha1'
require 'json'

module MulukhiyaTootProxy
  class Mastodon
    def initialize(uri, token = nil)
      @uri = MastodonURI.parse(uri)
      @token = token
    end

    def account_id
      return account['id'].to_i
    end

    def account
      raise ExternalServiceError, "#{__method__}: access token not found." unless @token
      unless @account
        rows = Postgres.instance.execute('token_owner', {token: @token})
        @account = rows.first if rows.present?
      end
      return @account
    end

    def fetch_toot(id)
      return fetch(create_uri("/api/v1/statuses/#{id}"))
    end

    def toot(body)
      return HTTParty.post(create_uri, {
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

    def growi
      @growi ||= Growi.create({account_id: account_id})
      return @growi
    end

    def self.create_tag(word)
      return '#' + word.strip.gsub(/[^[:alnum:]]+/, '_').sub(/^_/, '').sub(/_$/, '')
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
      raise ExternalServiceError, "外部リソースから取得できません。 (#{e.message})"
    end

    def create_uri(href = '/api/v1/statuses')
      uri = @uri.clone
      uri.path = href
      return uri
    end
  end
end
