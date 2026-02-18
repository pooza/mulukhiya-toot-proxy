module Mulukhiya
  class WebhookController < Controller
    post '/admin' do
      raise Ginseng::ServiceUnavailableError, 'Info agent not configured' unless info_agent_service
      verify_admin_webhook!(@body)
      admin_payload = JSON.parse(@body)
      event = detect_admin_event(admin_payload)
      raise Ginseng::NotFoundError, 'Unknown event' unless event
      reporter = Event.new(event, {sns: info_agent_service}).dispatch(admin_payload)
      @renderer.message = reporter.to_h
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/:digest' do
      raise Ginseng::NotFoundError, 'Not Found' unless webhook
      if payload.errors.present?
        @renderer.status = 422
        @renderer.message = payload.errors
      else
        reporter = webhook.post(payload)
        @renderer.message = reporter.response.parsed_response
        @renderer.status = reporter.response.code
      end
      return @renderer.to_s
    rescue => e
      e.alert
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/:digest' do
      raise Ginseng::NotFoundError, 'Not Found' unless webhook
      @renderer.message = {message: 'OK'}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def webhook
      return nil unless controller_class.webhook?
      @webhook ||= Webhook.create(params[:digest])
      return @webhook
    end

    def payload
      @payload ||= SlackWebhookPayload.new(params)
      return @payload
    end

    private

    def verify_admin_webhook!(raw_body)
      secret = config['/agent/info/webhook/secret']
      raise Ginseng::AuthError, 'Webhook secret not configured' unless secret
      if (signature = request.env['HTTP_X_HUB_SIGNATURE'])
        expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"
        unless Rack::Utils.secure_compare(signature, expected)
          raise Ginseng::AuthError, 'Invalid signature'
        end
      elsif (hook_secret = request.env['HTTP_X_MISSKEY_HOOK_SECRET'])
        unless Rack::Utils.secure_compare(hook_secret, secret)
          raise Ginseng::AuthError, 'Invalid secret'
        end
      else
        raise Ginseng::AuthError, 'Missing webhook signature'
      end
    end

    def detect_admin_event(payload)
      return :user_created if payload['event'] == 'account.created'
      return :user_created if payload['type'] == 'userCreated'
      return nil
    end
  end
end
