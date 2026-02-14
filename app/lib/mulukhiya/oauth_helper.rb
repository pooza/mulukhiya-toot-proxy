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

    def self.create_oauth_state(type:, sns_type:)
      code_verifier = generate_code_verifier
      code_challenge = generate_code_challenge(code_verifier)
      state = generate_state
      storage.set(state, {code_verifier:, type:, sns_type:})
      return {state:, code_challenge:}
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
