require 'omniauth'
require 'omniauth-twitter'

module Mulukhiya
  class AuthController < Controller
    enable :sessions

    use OmniAuth::Builder do
      provider :twitter, TwitterService.consumer_key, TwitterService.consumer_secret
    end

    get '/auth/twitter/callback' do
      errors = TwitterAuthContract.new.exec(params)
      if errors.present?
        @renderer.status = 422
        @renderer.message = errors
      elsif @sns.account
        @sns.account.config.update(twitter: request.env['omniauth.auth'][:credentials])
        @renderer = SlimRenderer.new
        @renderer.template = 'config'
      else
        @renderer.status = 403
      end
      return @renderer.to_s
    end
  end
end
