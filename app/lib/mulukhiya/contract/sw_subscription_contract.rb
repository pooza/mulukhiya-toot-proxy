module Mulukhiya
  class SwSubscriptionContract < Contract
    params do
      required(:endpoint).value(:string)
      required(:auth).value(:string)
      required(:publickey).value(:string)
      optional(:sendReadMessage).value(:bool)
    end

    rule(:endpoint) do
      key.failure('空欄です。') if value.empty?
      key.failure('https:// で始まる URL を指定してください。') unless value.start_with?('https://')
      key.failure('公開ホストの URL を指定してください。') unless SwSubscriptionContract.public_http_uri?(value)
      key.failure('許可されたホストの URL を指定してください。') unless SwSubscriptionContract.allowed_host?(value)
    end

    rule(:auth) do
      key.failure('空欄です。') if value.empty?
    end

    rule(:publickey) do
      key.failure('空欄です。') if value.empty?
    end

    RESERVED_TLDS = [
      'local',
      'internal',
      'lan',
      'test',
      'localhost',
      'example',
      'invalid',
      'onion',
    ].freeze

    def self.public_http_uri?(uri_string)
      uri = Ginseng::URI.parse(uri_string)
      return false unless uri.scheme == 'https'
      host = uri.host.to_s.downcase
      return false unless host.present?
      return false unless host.include?('.')
      return false if host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/)
      return false if host.match?(/\A\[.*\]\z/)
      return false if RESERVED_TLDS.include?(host.split('.').last)
      return true
    rescue
      return false
    end

    def self.allowed_host?(uri_string)
      allowed = Config.instance['/misskey/sw_subscription/allowed_hosts'] || []
      return true if allowed.empty?
      uri = Ginseng::URI.parse(uri_string)
      host = uri.host.to_s.downcase
      return allowed.map {|h| h.to_s.downcase}.include?(host)
    rescue
      return false
    end
  end
end
