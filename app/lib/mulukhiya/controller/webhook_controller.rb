module Mulukhiya
  class WebhookController < Controller
    post '/:digest' do
      raise Ginseng::AuthError, 'Unauthorized' unless controller_class.webhook?
      if webhook
        if payload.errors.present?
          @renderer.status = 422
          @renderer.message = payload.errors
        else
          reporter = webhook.post(payload)
          @renderer.message = reporter.response.parsed_response
          @renderer.status = reporter.response.code
        end
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/:digest' do
      raise Ginseng::AuthError, 'Unauthorized' unless controller_class.webhook?
      if webhook
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    rescue => e
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def webhook
      @webhook ||= Webhook.create(params[:digest])
      return @webhook
    end

    def payload
      @payload ||= GitHubWebhookPayload.new(params) if @headers['X-Github-Hook-Id']
      @payload ||= SlackWebhookPayload.new(params)
      return @payload
    end
  end
end
