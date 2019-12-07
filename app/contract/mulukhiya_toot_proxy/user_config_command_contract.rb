require 'dry-validation'

module MulukhiyaTootProxy
  class UserConfigCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
    end

    rule(:command) do
      key.failure('コマンド名が空欄です。') unless value.present?
    end
  end
end
