require 'time'

module Mulukhiya
  class AnnictService
    def initialize(token = nil)
      @config = Config.instance
      @token = token
      @per_page = @config['/annict/api/per_page']
      @storage = AnnictStorage.new
    end

    def recent_records
      return enum_for(__method__) unless block_given?
      records do |record|
        break if updated_at && Time.parse(record['created_at']) <= updated_at
        yield record
      end
    end

    def records
      return enum_for(__method__) unless block_given?
      uri = api_service.create_uri('/v1/activities')
      uri.query_values = {
        filter_user_id: account['id'],
        fields: @config['/annict/api/records/fields'].join(','),
        page: 1,
        per_page: @per_page,
        sort_id: 'desc',
        access_token: @token,
      }
      r = api_service.get(uri)
      raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
      r['activities'].each do |activity|
        next unless activity['action'] == 'create_record'
        yield activity
      end
    end

    def recent_reviews
      return enum_for(__method__) unless block_given?
      reviews do |review|
        break if updated_at && Time.parse(review['created_at']) <= updated_at
        yield review
      end
    end

    def reviews
      return enum_for(__method__) unless block_given?
      reviewed_works.each do |work|
        uri = api_service.create_uri('/v1/reviews')
        uri.query_values = {
          filter_work_id: work['work']['id'],
          fields: @config['/annict/api/reviews/fields'].join(','),
          page: 1,
          per_page: @per_page,
          sort_id: 'desc',
          access_token: @token,
        }
        r = api_service.get(uri)
        raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
        r['reviews'].each do |review|
          next unless review['user']['id'] == account['id']
          yield review
        end
      end
    end

    def reviewed_works
      return enum_for(__method__) unless block_given?
      uri = api_service.create_uri('/v1/activities')
      uri.query_values = {
        filter_user_id: account['id'],
        fields: @config['/annict/api/reviewed_works/fields'].join(','),
        page: 1,
        per_page: @per_page,
        sort_id: 'desc',
        access_token: @token,
      }
      r = api_service.get(uri)
      raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
      r['activities'].each do |activity|
        next unless activity['action'] == 'create_review'
        yield activity
      end
    end

    def create_body(values, type)
      body_template = Template.new("annict/#{type}_body")
      body_template[type] = values.deep_stringify_keys
      title_template = Template.new("annict/#{type}_title")
      title_template[type] = values.deep_stringify_keys
      if body_template.to_s.match?(@config['/annict/spoiler/pattern'])
        body = {
          'spoiler_text' => title_template.to_s.tr("\n", ' ').strip,
          'text' => body_template.to_s.lstrip,
        }
      else
        body = {'text' => [title_template.to_s, body_template.to_s].join}
      end
      uri = Ginseng::URI.parse(body_template[type].dig('work', 'images', 'recommended_url'))
      body['attachments'] = [{'image_url' => uri.to_s}] if uri&.absolute?
      return body
    end

    def account
      unless @account
        uri = api_service.create_uri('/v1/me')
        uri.query_values = {
          fields: @config['/annict/api/me/fields'].join(','),
          access_token: @token,
        }
        r = api_service.get(uri)
        raise Ginseng::GatewayError, "Invalid response (#{r.code})" unless r.code == 200
        @account = r.parsed_response
      end
      return @account
    end

    alias me account

    def updated_at
      @updated_at ||= Time.parse(@storage[account['id']]['time'])
      return @updated_at
    rescue
      return nil
    end

    def updated_at=(time)
      return if updated_at && Time.parse(time.to_s) < updated_at
      @storage[account['id']] = {time: time.to_s}
      @updated_at = nil
    end

    def api_service
      unless @api_service
        @api_service = HTTP.new
        @api_service.base_uri = @config['/annict/urls/api']
      end
      return @api_service
    end

    def oauth_service
      unless @oauth_service
        @oauth_service = HTTP.new
        @oauth_service.base_uri = @config['/annict/urls/oauth']
      end
      return @oauth_service
    end

    def auth(code)
      return oauth_service.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
          'client_id' => AnnictService.client_id,
          'client_secret' => AnnictService.client_secret,
          'code' => code,
        },
      })
    end

    def oauth_uri
      uri = oauth_service.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: AnnictService.client_id,
        response_type: 'code',
        redirect_uri: @config['/annict/oauth/redirect_uri'],
        scope: @config['/annict/oauth/scopes'].join(' '),
      }
      return uri
    end

    def self.client_id
      return Config.instance['/annict/oauth/client/id']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.client_secret
      return Config.instance['/annict/oauth/client/secret']
    rescue Ginseng::ConfigError
      return nil
    end

    def self.config?
      return false if client_id.nil?
      return false if client_secret.nil?
      return true
    end
  end
end
