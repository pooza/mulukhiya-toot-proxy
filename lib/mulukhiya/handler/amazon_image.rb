require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler'
require 'mulukhiya/mastodon'

module MulukhiyaTootProxy
  class AmazonImageHandler < Handler
    def exec(body, headers = {})
      cnt = 1
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      return unless links.present?
      uri = AmazonURI.parse(links.first)
      return unless uri.amazon?
      return unless uri.asin.present?
      if uri.image_uri.present?
        body['media_ids'] ||= []
        instance = mastodon_instance(headers)
        body['media_ids'].push(instance.upload_remote_resource(uri.image_uri))
      end
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

    def mastodon_instance(headers)
      return Mastodon.new(
        (@config['local']['instance_url'] || "https://#{headers['HTTP_HOST']}"),
        headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
    end
  end
end
