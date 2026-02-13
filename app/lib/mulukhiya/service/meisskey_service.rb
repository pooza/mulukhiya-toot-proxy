module Mulukhiya
  class MeisskeyService < Ginseng::Fediverse::MeisskeyService
    include Package
    include SNSMethods
    include SNSServiceMethods

    alias info nodeinfo

    alias note post

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

    def create_headers(headers = {})
      dest = super
      dest.delete_if {|k, _| k.to_s.downcase == 'cookie'}
      return dest
    end
  end
end
