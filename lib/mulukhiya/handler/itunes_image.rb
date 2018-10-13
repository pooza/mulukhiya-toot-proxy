require 'mulukhiya/spotify_uri'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class ItunesImageHandler < Handler
    def exec(body, headers = {})
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      body['media_ids'] ||= []
      links.each do |link|
        uri = ItunesURI.parse(link)
        next unless uri.itunes?
        next unless uri.track_id.present?
        next unless uri.image_uri.present?
        body['media_ids'].push(@mastodon.upload_remote_resource(uri.image_uri))
        increment!
        break
      end
    end
  end
end
