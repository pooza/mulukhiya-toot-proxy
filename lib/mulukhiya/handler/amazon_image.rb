require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class AmazonImageHandler < Handler
    def exec(body, headers = {})
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      body['media_ids'] ||= []
      links.each do |link|
        uri = AmazonURI.parse(link)
        next unless uri.amazon?
        next unless uri.asin.present?
        next unless uri.image_uri.present?
        body['media_ids'].push(@mastodon.upload_remote_resource(uri.image_uri))
        increment!
        return
      end
    end
  end
end
