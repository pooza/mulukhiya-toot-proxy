module Mulukhiya
  class MastodonService < Ginseng::Fediverse::MastodonService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias toot post

    def update_status(status, body, params = {})
      status = status_class[status] unless status.is_a?(status_class)
      body = {status: body.to_s} unless body.is_a?(Hash)
      body.deep_symbolize_keys!
      body[:media_ids] ||= status.attachments.map(&:id)
      body[:in_reply_to_id] ||= status.in_reply_to_id
      body[:spoiler_text] ||= status.spoiler_text
      body[:visibility] ||= status.visibility
      response = http.put("/api/v1/statuses/#{status.id}", {
        body: body.compact,
        headers: create_headers(params[:headers]),
      })
      return self.class.create_status_info(response.body)
    end

    def statuses(params = {})
      case params[:type].to_sym
      when :account
        uri = create_uri("/api/v1/accounts/#{account.id}/statuses")
        uri.query_values = params.except(:type).compact
        response = http.get(uri)
      else
        response = http.get('/api/v1/timelines/home', {headers: create_headers(params[:headers])})
      end
      return response.parsed_response.map {|s| self.class.create_status_info(s)}
    end

    def search_status_id(status)
      status = status.id if status.is_a?(status_class)
      return super
    end

    def search_attachment_id(attachment)
      attachment = attachment.id if attachment.is_a?(attachment_class)
      return super
    end

    def search(keyword, params = {})
      params[:limit] ||= config['/mastodon/search/limit']
      return super
    end

    def register_filter(params = {})
      params.deep_symbolize_keys!
      params[:account_id] = account.id
      params[:phrase] ||= params[:tag]&.to_hashtag
      super
      return unless params[:minutes]
      Sidekiq.set_schedule("filter_unregister_#{account.username}", {
        at: params[:minutes].minutes.after,
        class: 'Mulukhiya::FilterUnregisterWorker',
        args: [params],
      })
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

    def self.create_status_info(status)
      status = JSON.parse(status) unless status.is_a?(Hash)
      parser = TootParser.new(TootParser.sanitize(status['content']))
      service = new
      return status.merge(
        created_at_str: Time.parse(status['created_at']).getlocal.strftime('%Y/%m/%d %H:%M:%S'),
        webui_url: service.create_uri("/mulukhiya/app/status/#{status['id']}").to_s,
        body: parser.body,
        taggable: status['visibility'] == MastodonController.visibility_name(:public),
        footer: parser.footer,
        footer_tags: TagContainer.scan(parser.footer)
          .filter_map {|tag| Environment.hash_tag_class.get(name: tag)}
          .map(&:to_h),
        visibility_icon: TootParser.visibility_icon(status['visibility']),
      )
    end
  end
end
