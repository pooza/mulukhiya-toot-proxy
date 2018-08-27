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
        options[:associate_tag] = @config['local']['amazon']['associate_id']
      end
    end

    def exec(body, headers = {})
      links = body['status'].scan(%r{https?://[^\s[:cntrl:]]+})
      return unless links.present?
      uri = AmazonURI.parse(links.first)
      return unless uri.amazon?

      response = Amazon::Ecs.item_lookup(uri.asin, {country: 'jp', response_group: 'Images'})
      raise response.error if response.has_error?
      raise "ASIN #{uri.asin} not found." unless response.items.present?
      body['media_ids'] ||= []
      body['media_ids'].push(upload(response.items.first.get('LargeImage/URL'), headers))
      increment!
    end

    private

    def upload(url, headers)
      mastodon = Mastodon.new(
        (@config['local']['instance_url'] || "https://#{headers['HTTP_HOST']}"),
        headers['HTTP_AUTHORIZATION'].split(/\s+/)[1],
      )
      return mastodon.upload_remote_resource(url)
    end
  end
end
