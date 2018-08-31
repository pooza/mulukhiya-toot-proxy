require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler'
require 'mulukhiya/mastodon'
require 'mulukhiya/amazon_service'

module MulukhiyaTootProxy
  class AmazonImageHandler < Handler
    def exec(body, headers = {})
      cnt = 1
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      return unless links.present?
      uri = AmazonURI.parse(links.first)
      return if !uri.amazon? || !uri.asin.present?
      image_uri = AmazonService.new.image_uri(uri.asin)
      body['media_ids'] ||= []
      body['media_ids'].push(mastodon(headers).upload_remote_resource(image_uri))
      increment!
    rescue Amazon::RequestError => e
      raise "#{e.class}: retrying #{retry_limit} times." if retry_limit < cnt
      sleep(1)
      cnt += 1
      retry
    end

    private

    def retry_limit
      return @config['application']['amazon_image']['retry_limit']
    end

    def mastodon(headers)
      return Mastodon.new(
        (@config['local']['instance_url'] || "https://#{headers['HTTP_HOST']}"),
        headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
    end
  end
end
