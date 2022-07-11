module Mulukhiya
  class AnnictService
    include Package
    include SNSMethods
    attr_reader :timestamps, :accounts

    def initialize(token = nil)
      @token = (token.decrypt rescue token)
      @timestamps = AnnictTimestampStorage.new
      @accounts = AnnictAccountStorage.new
    end

    def recent_records
      return enum_for(__method__) unless block_given?
      records do |record|
        break if updated_at && Time.parse(record['created_at']) <= updated_at
        yield record
      end
    end

    def records(&block)
      return enum_for(__method__) unless block
      uri = rest_api_service.create_uri('/v1/activities')
      uri.query_values = {
        filter_user_id: account['id'],
        fields: config['/annict/api/records/fields'].join(','),
        page: 1,
        per_page: config['/annict/api/records/limit'],
        sort_id: 'desc',
        access_token: @token,
      }
      sleep(config['/annict/interval/seconds'])
      rest_api_service.get(uri)['activities'].select {|v| v['action'] == 'create_record'}.each(&block)
    end

    def recent_reviews
      return enum_for(__method__) unless block_given?
      reviews do |review|
        break if updated_at && Time.parse(review['created_at']) <= updated_at
        yield review
      end
    end

    def reviews(&block)
      return enum_for(__method__) unless block
      reviewed_works.each do |work|
        uri = rest_api_service.create_uri('/v1/reviews')
        uri.query_values = {
          filter_work_id: work.dig('work', 'id'),
          fields: config['/annict/api/reviews/fields'].join(','),
          page: 1,
          per_page: config['/annict/api/reviews/limit'],
          sort_id: 'desc',
          access_token: @token,
        }
        sleep(config['/annict/interval/seconds'])
        rest_api_service.get(uri)['reviews']
          .select {|review| review.dig('user', 'id') == account['id']}
          .each(&block)
      end
    end

    def reviewed_works(&block)
      return enum_for(__method__) unless block
      uri = rest_api_service.create_uri('/v1/activities')
      uri.query_values = {
        filter_user_id: account['id'],
        fields: config['/annict/api/reviewed_works/fields'].join(','),
        page: 1,
        per_page: config['/annict/api/reviewed_works/limit'],
        sort_id: 'desc',
        access_token: @token,
      }
      sleep(config['/annict/interval/seconds'])
      rest_api_service.get(uri)['activities']
        .select {|activity| activity['action'] == 'create_review'}
        .each(&block)
    end

    def create_payload(values, type)
      body_template = Template.new("annict/#{type}_body")
      body_template[type] = values
      title_template = Template.new("annict/#{type}_title")
      title_template[type] = values
      body = {text: [title_template.to_s, body_template.to_s].join}
      if body_template.to_s.match?(config['/spoiler/pattern'])
        body[:text] = body_template.to_s.lstrip
        body[:spoiler_text] = "#{title_template.to_s.tr("\n", ' ').strip} （ネタバレ）"
      end
      return SlackWebhookPayload.new(body)
    end

    def account
      unless accounts[@token]
        uri = rest_api_service.create_uri('/v1/me')
        uri.query_values = {
          fields: config['/annict/api/me/fields'].join(','),
          access_token: @token,
        }
        sleep(config['/annict/interval/seconds'])
        accounts[@token] = rest_api_service.get(uri).parsed_response
      end
      return accounts[@token]
    end

    def crawl(params = {})
      self.updated_at ||= Time.now
      times = []
      records = []
      crawl_set(params).each do |key, result|
        result.each do |record|
          times.push(Time.parse(record['created_at']))
          records.push(record)
          params[:webhook]&.post(create_payload(record, key)) unless params[:dryrun]
        end
      end
      self.updated_at = times.max if times.present? && !params[:dryrun]
      return records
    end

    def crawl_set(params = {})
      return {record: records, review: reviews} if params[:all]
      return {record: recent_records, review: recent_reviews}
    end

    alias me account

    def updated_at
      @updated_at ||= Time.parse(timestamps[account['id']]['time'])
      return @updated_at
    rescue
      return nil
    end

    def updated_at=(time)
      return if updated_at && Time.parse(time.to_s) < updated_at
      timestamps[account['id']] = {time: time.to_s}
      @updated_at = nil
    end

    def rest_api_service
      unless @rest_api_service
        @rest_api_service = HTTP.new
        @rest_api_service.base_uri = config['/annict/urls/api/rest']
      end
      return @rest_api_service
    end

    alias api_service rest_api_service

    def graphql_api_service
      unless @graphql_api_service
        @graphql_api_service = HTTP.new
        @graphql_api_service.base_uri = config['/annict/urls/api/graphql']
      end
      return @graphql_api_service
    end

    def service
      unless @service
        @service = HTTP.new
        @service.base_uri = config['/annict/urls/default']
      end
      return @service
    end

    def auth(code)
      return service.post('/oauth/token', {
        headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
        body: {
          'grant_type' => 'authorization_code',
          'redirect_uri' => config['/annict/oauth/redirect_uri'],
          'client_id' => self.class.client_id,
          'client_secret' => self.class.client_secret,
          'code' => code,
        },
      })
    end

    def oauth_uri
      uri = service.create_uri('/oauth/authorize')
      uri.query_values = {
        client_id: self.class.client_id,
        response_type: 'code',
        redirect_uri: config['/annict/oauth/redirect_uri'],
        scope: self.class.oauth_scopes.join(' '),
      }
      return uri
    end

    def self.oauth_scopes(key = 'default')
      return config["/annict/oauth/scopes/#{key}"]
    end

    def self.client_id
      return config['/annict/oauth/client/id'] rescue nil
    end

    def self.client_secret
      return config['/annict/oauth/client/secret'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/annict/oauth/client/secret']
    end

    def self.config?
      return false if client_id.nil?
      return false if client_secret.nil?
      return true
    end

    def self.create_record_uri(work_id, episode_id)
      return new.service.create_uri("/works/#{work_id}/episodes/#{episode_id}")
    end

    def self.create_review_uri(work_id)
      return new.service.create_uri("/works/#{work_id}/records")
    end

    def self.create_episode_number_text(str)
      return unless str
      return str unless match = str.match(/[[:digit:]][.[:digit:]]*/)
      return "#{match}話"
    end

    def self.crawl_all(params = {})
      return unless controller_class.annict?
      accounts = AnnictAccountStorage.accounts
      bar = ProgressBar.create(total: accounts.count)
      results = {}
      accounts.each do |account|
        results[account.acct.to_s] = account.annict.crawl(params.merge(webhook: account.webhook))
      rescue => e
        e.log(acct: account.acct.to_s)
      ensure
        bar&.increment
      end
      bar&.finish
      return unless Environment.rake?
      results.each do |acct, result|
        puts({acct:, result:}.to_yaml)
      end
    end
  end
end
