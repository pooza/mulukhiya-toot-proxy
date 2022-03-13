module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

    def search_dupllicated_attachment(attachment, params = {})
      attachment = attachment.to_h[:md5] if attachment.is_a?(attachment_class)
      response = super
      return response if params[:response] == :raw
      return attachment_class[response.parsed_response.first['id']]
    end

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
  end
end
