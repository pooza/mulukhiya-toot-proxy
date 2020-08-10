module Mulukhiya
  class WebhookController < MisskeyController
    post '/mulukhiya/webhook/:digest' do
      errors = WebhookContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif webhook = Webhook.create(params[:digest])
        reporter = webhook.post(params)
        @renderer.message = reporter.response.parsed_response
        @renderer.status = reporter.response.code
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end

    get '/mulukhiya/webhook/:digest' do
      if Webhook.create(params[:digest])
        @renderer.message = {message: 'OK'}
      else
        @renderer.status = 404
      end
      return @renderer.to_s
    end
  end
end
