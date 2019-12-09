require 'dry-validation'

module MulukhiyaTootProxy
  class UserConfigCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
    end

    rule(:command) do
      key.failure('command: が正しくありません。') unless value == 'user_config'
    end
  end
end
