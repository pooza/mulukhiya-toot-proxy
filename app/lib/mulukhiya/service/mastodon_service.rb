module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    include SNSMethods
    include SNSServiceMethods

    def info
      return info.merge(metadata: {themeColor: theme_color})
    end

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

    def register_filter(params = {})
      params.deep_symbolize_keys!
      params[:account_id] = account.id
      params[:phrase] ||= params[:tag]&.to_hashtag
      super
    end

    def oauth_client(type = :default)
      return nil unless scopes = MastodonController.oauth_scopes(type)
      body = {
        client_name: MastodonController.oauth_client_name(type),
        website: config['/package/url'],
        redirect_uris: config['/mastodon/oauth/redirect_uri'],
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
        redirect_uri: config['/mastodon/oauth/redirect_uri'],
        scope: MastodonController.oauth_scopes(type).join(' '),
      }
      return uri
    end

    def notify(account, message, options = {})
      options.deep_symbolize_keys!
      message = [account.acct.to_s, message].join("\n")
      return post(
        MastodonController.status_field => message.ellipsize(max_post_text_length),
        MastodonController.spoiler_field => options[:spoiler_text],
        MastodonController.visibility_field => MastodonController.visibility_name(:direct),
        MastodonController.reply_to_field => options.dig(:response, :id),
      )
    end
  end
end
