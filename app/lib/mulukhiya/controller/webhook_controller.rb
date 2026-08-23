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
      # ⚠ **ここは `report_error` に寄せない (#4603)。**主な失敗は署名検証
      # (`AuthError`) と設定不備 (`ServiceUnavailableError`) で、**署名不一致を
      # 黙らせたくない**。4xx でも alert するのが正しい。
      e.alert
      @renderer.status = e.respond_to?(:status) ? e.status : 500
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    post '/:digest' do
      verify_webhook!
      if payload.errors.present?
        @renderer.status = 422
        @renderer.message = payload.errors
      else
        reporter = webhook.post(payload, {headers: forwarded_headers})
        @renderer.message = reporter.response.parsed_response
        @renderer.status = reporter.response.code
      end
      return @renderer.to_s
    rescue => e
      # ⚠ **消された・打ち間違えた webhook URL を叩かれただけ**で 404 になる
      # (#4603)。同じ `verify_webhook!` を通す `get '/:digest'` は `e.log` なので、
      # **同じ例外が GET なら静か・POST なら alert** という非対称になっていた。
      report_error(e)
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    get '/:digest' do
      verify_webhook!
      @renderer.message = {message: 'OK'}
      return @renderer.to_s
    rescue => e
      e.log
      @renderer.status = e.status
      @renderer.message = {error: e.message}
      return @renderer.to_s
    end

    def webhook
      @webhook ||= Webhook.create(params[:digest])
      return @webhook
    end

    def payload
      @payload ||= SlackWebhookPayload.new(params)
      return @payload
    end

    private

    def verify_webhook!
      unless controller_class.webhook?
        raise Ginseng::ServiceUnavailableError, 'Webhook is not enabled'
      end
      return if webhook
      raise Ginseng::NotFoundError,
        "Webhook not found (digest: #{params[:digest][0, 12]}...)"
    end

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
      return :user_approved if payload['event'] == 'account.approved'
      return :user_approved if payload['type'] == 'userCreated'
      return nil
    end
  end
end
