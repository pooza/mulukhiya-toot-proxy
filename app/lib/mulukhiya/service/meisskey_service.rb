module Mulukhiya
  class MeisskeyService < Ginseng::Fediverse::MeisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

    def update_status(status, body, params = {})
      return repost_status(status, body, params)
    end

    def oauth_client(type = :default)
      return nil unless scopes = MeisskeyController.oauth_scopes(type)
      body = {
        name: MeisskeyController.oauth_client_name(type),
        description: config['/package/description'],
        permission: scopes,
      }
      unless client = oauth_client_storage[body]
        client = http.post('/api/app/create', {body:}).body
        oauth_client_storage[body] = client
      end
      return JSON.parse(client)
    end

    def oauth_uri(type = :default)
      return nil unless oauth_client(type)
      response = http.post('/api/auth/session/generate', {
        body: {appSecret: oauth_client(type)['secret']},
      })
      return Ginseng::URI.parse(response['url'])
    end

    def notify(account, message, options = {})
      options.deep_symbolize_keys!
      message = [account.acct.to_s, message].join("\n")
      reply_to = options.dig(:response, :createdNote, :id) || options.dig(:response, :id)
      return post(
        MeisskeyController.status_field => message.ellipsize(max_post_text_length),
        MeisskeyController.spoiler_field => options[:spoiler_text],
        MeisskeyController.visible_users_field => [account.id],
        MeisskeyController.visibility_field => MeisskeyController.visibility_name(:direct),
        MeisskeyController.reply_to_field => reply_to,
      )
    end
  end
end
