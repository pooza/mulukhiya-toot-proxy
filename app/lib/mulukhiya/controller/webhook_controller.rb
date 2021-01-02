module Mulukhiya
  class WebhookController < Controller
    post '/:digest' do
      if errors = WebhookContract.new.exec(params)
        @renderer.status = 422
        @renderer.message = errors
      elsif webhook = Webhook.create(params[:digest])
        webhook.payload = GitHubWebhookPayload.new(params) if @headers['X-GitHub-Hook-ID']
        webhook.payload ||= SlackWebhookPayload.new(params)
        reporter = webhook.post
        @renderer.message = reporter.response.parsed_response
        @renderer.status = reporter.response.code
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/:digest' do
      if errors = WebhookContract.new.exec(params)
        @renderer.status = 422
        @renderer.message = errors
      elsif Webhook.create(params[:digest])
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end
  end
end
