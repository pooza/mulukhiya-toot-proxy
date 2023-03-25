module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

    def oauth_client(type = :default)
      return nil unless scopes = MisskeyController.oauth_scopes(type)
      body = {
        name: MisskeyController.oauth_client_name(type),
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
        MisskeyController.status_field => message.ellipsize(max_post_text_length),
        MisskeyController.spoiler_field => options[:spoiler_text],
        MisskeyController.visible_users_field => [account.id],
        MisskeyController.visibility_field => MisskeyController.visibility_name(:direct),
        MisskeyController.reply_to_field => reply_to,
      )
    end

    def create_command_uri(command)
      uri = create_uri('/share')
      uri.query_values = {text: command.to_yaml}
      return uri
    end
  end
end
