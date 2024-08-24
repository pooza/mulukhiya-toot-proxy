module Mulukhiya
  class MisskeyService < Ginseng::Fediverse::MisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

    def update_status(status, body, params = {})
      return repost_status(status, body, params)
    end

    def repost_status(status, body, params = {})
      status = status_class[status] unless status.is_a?(status_class)
      values = status.payload
      body = {status_field.to_sym => body.to_s} unless body.is_a?(Hash)
      body = values.merge(body.deep_symbolize_keys)
      if poll = status.poll
        body[:poll] = {choices: poll.choices}
      end
      body[:renoteId] = status.renoteId
      response = post(body.compact, params)
      delete_status(status.id, params)
      return response
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

    def self.parse_aid(aid)
      return Time.at((aid[0..7].to_i(36) / 1000) + 946_684_800, in: 'UTC').getlocal
    end
  end
end
