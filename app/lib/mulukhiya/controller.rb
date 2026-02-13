module Mulukhiya
  class Controller < Ginseng::Web::Sinatra
    include Package
    include SNSMethods

    attr_reader :sns, :reporter

    set :root, Environment.dir
    enable :method_override

    before do
      @reporter = Reporter.new
      @sns = sns_class.new
      @sns.token = token
    rescue => e
      e.log
      @sns.token = nil
    end

    not_found do
      @renderer = default_renderer_class.new
      @renderer.status = 404
      @renderer.message = Ginseng::NotFoundError.new("Resource #{request.path} not found.").to_h
      return @renderer.to_s
    end

    error do |e|
      @renderer = default_renderer_class.new
      @renderer.status = e.status
      @renderer.message = e.to_h.except(:backtrace).merge(error: e.message)
      e.alert
      return @renderer.to_s
    end

    def name
      return self.class.to_s.split('::').last.sub(/Controller$/, '').underscore
    end

    alias underscore name

    def token
      return nil
    end

    def api_version
      return params[:version].sub(/^v/, '').to_i
    end

    def verify_token_integrity!
      expected = token
      return unless expected
      return if sns.token == expected
      logger.error(
        event: 'token_mismatch',
        expected: expected.first(8),
        actual: sns.token&.first(8),
        path: request.path,
      )
      raise Ginseng::AuthError, 'Token integrity check failed'
    end

    def verify_account_integrity!(response)
      return unless response&.parsed_response.is_a?(Hash)
      posted_id = response.parsed_response.dig('account', 'id') \
        || response.parsed_response.dig('createdNote', 'user', 'id')
      return unless posted_id
      return if posted_id.to_s == sns.account&.id.to_s
      logger.error(
        event: 'account_mismatch_detected',
        expected_account: sns.account&.id,
        posted_as: posted_id,
        path: request.path,
      )
    end

    private

    def path_prefix
      return '' if Environment.test?
      return "/mulukhiya/#{name}"
    end
  end
end
