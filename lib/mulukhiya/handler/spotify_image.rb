require 'mulukhiya/spotify_uri'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class SpotifyImageHandler < Handler
    def exec(body, headers = {})
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      body['media_ids'] ||= []
      links.each do |link|
        uri = SpotifyURI.parse(link)
        next unless uri.spotify?
        next unless uri.track_id.present?
        next unless uri.image_uri.present?
        body['media_ids'].push(@mastodon.upload_remote_resource(uri.image_uri))
        increment!
        break
      end
    end
  end
end
