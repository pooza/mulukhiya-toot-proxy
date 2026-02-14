module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

    def draft(body, params = {})
      body = {text: body.to_s} unless body.is_a?(Hash)
      body = body.deep_symbolize_keys
      body[:replyId] = params.dig(:reply, :id) if params[:reply]
      body.delete(:text) unless body[:text].present?
      body.delete(:cw) unless body[:cw].present?
      body.delete(:fileIds) unless body[:fileIds].present?
      body[:i] ||= token
      return http.post('/api/notes/drafts/create', {
        body: body.compact,
        headers: create_headers(params[:headers]),
      })
    end

    def update_draft(body, params = {})
      body = {text: body.to_s} unless body.is_a?(Hash)
      body = body.deep_symbolize_keys
      body[:replyId] = params.dig(:reply, :id) if params[:reply]
      body.delete(:text) unless body[:text].present?
      body.delete(:cw) unless body[:cw].present?
      body.delete(:fileIds) unless body[:fileIds].present?
      body[:i] ||= token
      return http.post('/api/notes/drafts/update', {
        body: body.compact,
        headers: create_headers(params[:headers]),
      })
    end

    def repost(status, body, params = {})
      status = status_class[status] unless status.is_a?(status_class)
      values = status.payload
      body = {status_field.to_sym => body.to_s} unless body.is_a?(Hash)
      body = values.merge(body.deep_symbolize_keys)
      body[:renoteId] = status.renoteId
      response = post(body.compact, params)
      delete_status(status.id, params)
      return response
    end

    def update_account(account, params = {})
    end

    def oauth_client_id
      return create_uri('/mulukhiya/app/home').to_s
    end

    def oauth_uri(type = :default)
      return oauth_uri_with_pkce(type)
    end

    def oauth_server_metadata
      @oauth_server_metadata ||= http.get('/.well-known/oauth-authorization-server').parsed_response
    rescue
      nil
    end

    def oauth_authorize_endpoint
      if (metadata = oauth_server_metadata) && metadata['authorization_endpoint']
        return URI.parse(metadata['authorization_endpoint']).path
      end
      return '/oauth/authorize'
    end

    def oauth_authorize_params(type = :default)
      scopes = MisskeyController.oauth_scopes(type)
      return nil if scopes.empty?
      return {
        client_id: oauth_client_id,
        scope: scopes.join(' '),
      }
    end

    def oauth_token_request(code, code_verifier:, redirect_uri:, type: :default)
      return oauth2_auth(
        code,
        redirect_uri:,
        code_verifier:,
        client_id: oauth_client_id,
      )
    end

    def create_headers(headers = {})
      dest = super
      dest.delete_if {|k, _| k.to_s.downcase == 'cookie'}
      return dest
    end

    def self.parse_aid(aid)
      return Time.at((aid[0..7].to_i(36) / 1000) + 946_684_800, in: 'UTC').getlocal
    end
  end
end
