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
      return false if RESERVED_TLDS.include?(host.split('.').last)
      return RemoteHost.public?(host)
    rescue
      return false
    end

    # NOTE: allowed_hosts が空配列のとき allow-all となるのは意図したデフォルト
    # （#4332 wontfix）。endpoint は W3C Push API がブラウザ/OS の push サービス
    # （FCM / Mozilla / Apple / WNS 等）から払い出す URL で、ホスト集合はベンダー
    # 管理かつ可変のため安定した allowlist を列挙できない。内部宛 SSRF は
    # public_http_uri?（RESERVED_TLDS + RemoteHost.public? の DNS 解決、#4271）で
    # 別途遮断済み。allowed_hosts は既知 push ゲートウェイに絞りたい運用者向けの
    # opt-in な二次防御として残す。
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
