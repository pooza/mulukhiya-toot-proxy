require 'securerandom'

module Mulukhiya
  module OAuthHelper
    def self.generate_code_verifier
      return SecureRandom.urlsafe_base64(64)
    end

    def self.generate_code_challenge(verifier)
      digest = Digest::SHA256.digest(verifier)
      return Base64.urlsafe_encode64(digest, padding: false)
    end

    def self.generate_state
      return SecureRandom.urlsafe_base64(32)
    end

    # ⚠ `browser` は、state を発行したブラウザの目印（Cookie の値）のダイジェスト (#4726)。
    # callback で同じブラウザから戻ってきたかを突き合わせる。→ `browser_digest`
    def self.create_oauth_state(sns_type:, browser: nil)
      code_verifier = generate_code_verifier
      code_challenge = generate_code_challenge(code_verifier)
      state = generate_state
      storage.set(state, {code_verifier:, sns_type:, browser:}.compact)
      return {state:, code_challenge:}
    end

    # ブラウザの目印（Cookie の値）のダイジェスト。空なら nil (#4726)。
    #
    # ⚠ Redis には値そのものでなくダイジェストを置く（Redis を読めても Cookie を作れない）。
    def self.browser_digest(nonce)
      return nil if nonce.to_s.empty?
      return Digest::SHA256.hexdigest(nonce.to_s)
    end

    def self.consume_oauth_state(state)
      return storage.consume(state)
    end

    def self.storage
      @storage ||= OAuthStateStorage.new
      return @storage
    end
  end
end
