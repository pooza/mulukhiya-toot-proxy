require 'mulukhiya/amazon_uri'
require 'mulukhiya/handler'
require 'mulukhiya/mastodon'
require 'amazon/ecs'

module MulukhiyaTootProxy
  class AmazonImageHandler < Handler
    def initialize
      super
      Amazon::Ecs.configure do |options|
        options[:AWS_access_key_id] = @config['local']['amazon']['access_key']
        options[:AWS_secret_key] = @config['local']['amazon']['secret_key']
        options[:associate_tag] = @config.associate_tag
      end
    end

    def exec(body, headers = {})
      cnt = 1
      uri = AmazonURI.parse(body['status'].scan(%r{https?://[^\s[:cntrl:]]+}).first)
      return unless uri.amazon?
      response = Amazon::Ecs.item_lookup(uri.asin, {country: 'jp', response_group: 'Images'})
      raise response.error if response.has_error?
      body['media_ids'] ||= []
      body['media_ids'].push(upload(response.items.first.get('LargeImage/URL'), headers))
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

    def upload(url, headers)
      mastodon = Mastodon.new(
        (@config['local']['instance_url'] || "https://#{headers['HTTP_HOST']}"),
        headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
      return mastodon.upload_remote_resource(url)
    end
  end
end
