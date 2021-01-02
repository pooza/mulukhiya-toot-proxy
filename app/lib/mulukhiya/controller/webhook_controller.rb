module Mulukhiya
  class WebhookController < Controller
    post '/:digest' do
      Slack.broadcast(params)
      if webhook = Webhook.create(params[:digest])
        webhook.payload = GitHubWebhookPayload.new(params) if @headers['X-GitHub-Hook-ID']
        webhook.payload ||= SlackWebhookPayload.new(params)
        if webhook.payload.errors.present?
          @renderer.status = 422
          @renderer.message = webhook.payload.errors
        else
          reporter = webhook.post
          @renderer.message = reporter.response.parsed_response
          @renderer.status = reporter.response.code
        end
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/:digest' do
      if Webhook.create(params[:digest])
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end
  end
end
