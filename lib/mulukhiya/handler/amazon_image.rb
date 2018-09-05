require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler'

module MulukhiyaTootProxy
  class AmazonImageHandler < Handler
    def exec(body, headers = {})
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      return unless links.present?
      uri = AmazonURI.parse(links.first)
      return unless uri.amazon?
      return unless uri.asin.present?
      return unless uri.image_uri.present?

      body['media_ids'] ||= []
      body['media_ids'].push(@mastodon.upload_remote_resource(uri.image_uri))
      increment!
    end
  end
end
