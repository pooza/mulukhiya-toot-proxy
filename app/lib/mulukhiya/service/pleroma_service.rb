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

    def create_tag_uri(tag)
      return create_uri("/tag/#{tag.to_hashtag_base}")
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

    def notify(account, message, options = {})
      options.deep_symbolize_keys!
      message = [account.acct.to_s, message].join("\n")
      return post(
        PleromaController.status_field => message.ellipsize(max_post_text_length),
        PleromaController.spoiler_field => options[:spoiler_text],
        PleromaController.visibility_field => PleromaController.visibility_name(:direct),
        PleromaController.reply_to_field => options.dig(:response, :id),
      )
    end
  end
end
