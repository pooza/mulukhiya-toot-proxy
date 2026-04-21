module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    def nodeinfo
      return NodeInfo.instance.data if NodeInfo.instance.cached?
      return super.merge(metadata: {themeColor: theme_color})
    rescue => e
      e.log
      return {}
    end

    alias info nodeinfo

    alias note post

    def theme_color
      @theme_color ||= fetch_meta_theme_color || config['/misskey/theme/color']
      return @theme_color
    end

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

    def oauth_client_id
      return create_uri('/mulukhiya/app/home').to_s
    end

    def oauth_uri
      return oauth_uri_with_pkce
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

    def oauth_authorize_params
      scopes = MisskeyController.oauth_scopes
      return nil if scopes.empty?
      return {
        client_id: oauth_client_id,
        scope: scopes.join(' '),
      }
    end

    def oauth_token_endpoint
      if (metadata = oauth_server_metadata) && metadata['token_endpoint']
        return URI.parse(metadata['token_endpoint']).path
      end
      return '/oauth/token'
    end

    def oauth_token_request(code, code_verifier:, redirect_uri:)
      return http.post(oauth_token_endpoint, {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'code' => code,
          'redirect_uri' => redirect_uri,
          'code_verifier' => code_verifier,
          'client_id' => oauth_client_id,
        },
      })
    end

    def fetch_avatar_decorations
      response = http.post('/api/get-avatar-decorations', {
        body: {},
        headers: create_headers,
      })
      return response.parsed_response
    end

    def emoji_palettes(account)
      row = Postgres.first(:emoji_palettes, {account_id: account.id})
      assignments = emoji_palette_assignments_for(account)
      return {
        palettes: parse_emoji_palette_entries(row&.dig(:value)),
        palette_for_reaction: assignments['emojiPaletteForReaction'],
        palette_for_main: assignments['emojiPaletteForMain'],
      }
    end

    def fetch_account_detail
      return http.post('/api/i', {
        body: {i: token},
        headers: create_headers,
      }).parsed_response
    end

    def update_account(params = {})
      body = params.deep_symbolize_keys
      body[:i] ||= token
      return http.post('/api/i/update', {
        body: body.compact,
        headers: create_headers,
      })
    end

    def create_headers(headers = {})
      dest = super
      dest.delete_if {|k, _| k.to_s.downcase == 'cookie'}
      return dest
    end

    def register_sw_subscription(account, params)
      row = {
        userId: account.id,
        endpoint: params[:endpoint],
        auth: params[:auth],
        publickey: params[:publickey],
      }
      existing = Misskey::SwSubscription.first(row)
      return {subscription: existing, state: :already_subscribed} if existing
      row[:id] = self.class.create_aid
      row[:sendReadMessage] = params[:sendReadMessage] == true
      subscription = Misskey::SwSubscription.create(row)
      invalidate_sw_subscription_cache(account.id)
      return {subscription:, state: :subscribed}
    end

    def unregister_sw_subscription(account, params)
      row = Misskey::SwSubscription.first(
        userId: account.id,
        endpoint: params[:endpoint],
        auth: params[:auth],
        publickey: params[:publickey],
      )
      return nil unless row
      row.delete
      invalidate_sw_subscription_cache(account.id)
      return row
    end

    def self.parse_aid(aid)
      return Time.at((aid[0..7].to_i(36) / 1000) + 946_684_800, in: 'UTC').getlocal
    end

    def self.create_aid(time = Time.now)
      @aid_mutex ||= Mutex.new
      @aid_node ||= SecureRandom.random_number(36**4).to_s(36).rjust(4, '0')
      ms = ((time.to_f * 1000).to_i - 946_684_800_000)
      counter = @aid_mutex.synchronize do
        @aid_counter = ((@aid_counter || -1) + 1) % (36**4)
      end
      return '%{time}%{node}%{counter}' % {
        time: ms.to_s(36).rjust(8, '0'),
        node: @aid_node,
        counter: counter.to_s(36).rjust(4, '0'),
      }
    end

    private

    def invalidate_sw_subscription_cache(user_id)
      Ginseng::Redis::Service.new(url: config['/misskey/redis/dsn'])
        .del("kvcache:userSwSubscriptions:#{user_id}")
    rescue => e
      e.log(user_id:)
    end

    def fetch_meta_theme_color
      response = http.post('/api/meta', {body: {}})
      return response.parsed_response&.dig('themeColor')
    rescue
      return nil
    end

    def parse_emoji_palette_entries(value)
      value = JSON.parse(value) if value.is_a?(String)
      return [] unless value.is_a?(Array) && value.first.is_a?(Array) && value.first[1].is_a?(Array)
      return value.first[1].grep(Hash).map do |p|
        {id: p['id'], name: p['name'], emojis: p['emojis'] || []}
      end
    end

    def emoji_palette_assignments_for(account)
      row = Postgres.first(:emoji_palette_assignments, {account_id: account.id})
      return {} unless row
      value = row[:value]
      value = JSON.parse(value) if value.is_a?(String)
      prefs = value['preferences'] || {}
      return {
        'emojiPaletteForReaction' => prefs['emojiPaletteForReaction']&.dig(0, 1),
        'emojiPaletteForMain' => prefs['emojiPaletteForMain']&.dig(0, 1),
      }
    rescue
      return {}
    end
  end
end
