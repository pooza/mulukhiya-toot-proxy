module Mulukhiya
  class PleromaService < Ginseng::Fediverse::PleromaService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias toot post

    def search_status_id(status)
      case status
      in Pleroma::Status
        return status.id
      in Ginseng::URI
        response = @http.get(status, {follow_redirects: false})
        return response.headers['location'].match(%r{/notice/(.*)})[1]
      else
        return super
      end
    end

    def oauth_client(type = :default)
      return nil unless scopes = PleromaController.oauth_scopes(type)
      body = {
        client_name: PleromaController.oauth_client_name(type),
        website: config['/package/url'],
        redirect_uris: config['/pleroma/oauth/redirect_uri'],
        scopes: scopes.join(' '),
      }
      unless client = oauth_client_storage[body]
        client = http.post('/api/v1/apps', {body:}).body
        oauth_client_storage[body] = client
      end
      return JSON.parse(client)
    end

    def oauth_uri(type = :default)
      return nil unless oauth_client(type)
      uri = create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: oauth_client(type)['client_id'],
        response_type: 'code',
        redirect_uri: config['/pleroma/oauth/redirect_uri'],
        scope: PleromaController.oauth_scopes(type).join(' '),
      }
      return uri
    end

    def create_headers(headers = {})
      dest = super
      dest.delete_if {|k, _| k.to_s.downcase == 'cookie'}
      return dest
    end
  end
end
