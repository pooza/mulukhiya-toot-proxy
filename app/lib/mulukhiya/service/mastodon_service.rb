module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    include SNSMethods
    include SNSServiceMethods

    def nodeinfo
      return super.merge(metadata: {themeColor: theme_color})
    end

    alias info nodeinfo

    alias toot post

    def theme_color
      return config['/mastodon/theme/color']
    end

    def repost(status, body, params = {})
      status = status_class[status] unless status.is_a?(status_class)
      values = status.payload
      body = {status_field.to_sym => body.to_s} unless body.is_a?(Hash)
      body = values.merge(body.deep_symbolize_keys)
      delete_status(status.id, params)
      response = post(body.compact, params)
      return response
    end

    def search_status_id(status)
      status = status.id if status.is_a?(status_class)
      return super
    end

    def search_attachment_id(attachment)
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def oauth_client
      return nil unless scopes = MastodonController.oauth_scopes
      body = {
        client_name: MastodonController.oauth_client_name,
        website: config['/package/url'],
        redirect_uris: oauth_callback_uri,
        scopes: scopes.join(' '),
      }
      unless client = oauth_client_storage[body]
        client = http.post('/api/v1/apps', {body:}).body
        oauth_client_storage[body] = client
      end
      return JSON.parse(client)
    end

    def oauth_uri
      return oauth_uri_with_pkce
    end

    def oauth_authorize_endpoint
      return '/oauth/authorize'
    end

    def oauth_authorize_params
      return nil unless oauth_client
      return {
        client_id: oauth_client['client_id'],
        scope: MastodonController.oauth_scopes.join(' '),
      }
    end

    def oauth_token_request(code, code_verifier:, redirect_uri:)
      return nil unless oauth_client
      return http.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'code' => code,
          'redirect_uri' => redirect_uri,
          'client_id' => oauth_client['client_id'],
          'client_secret' => oauth_client['client_secret'],
          'code_verifier' => code_verifier,
        },
      })
    end

    def create_headers(headers = {})
      dest = super
      dest.delete_if {|k, _| k.to_s.downcase == 'cookie'}
      return dest
    end
  end
end
