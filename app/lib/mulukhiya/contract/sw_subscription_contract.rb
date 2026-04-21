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
    end

    rule(:auth) do
      key.failure('空欄です。') if value.empty?
    end

    rule(:publickey) do
      key.failure('空欄です。') if value.empty?
    end

    def self.public_http_uri?(uri_string)
      uri = Ginseng::URI.parse(uri_string)
      return false unless uri.scheme == 'https'
      host = uri.host
      return false unless host.present?
      return false unless host.include?('.')
      return false if host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/)
      return false if host.match?(/\A\[.*\]\z/)
      addrs = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address)
      return addrs.none? do |ip|
        addr = IPAddr.new(ip)
        addr.private? || addr.loopback? || addr.link_local?
      end
    rescue
      return false
    end
  end
end
