require 'dry-validation'

module MulukhiyaTootProxy
  class FilterCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:phrase).value(:string)
      optional(:tag).value(:string)
      optional(:action).value(:string)
    end

    rule(:command) do
      key.failure('コマンド名が正しくありません。') unless value == 'filter'
    end

    rule(:phrase, :tag) do
      key.failure('phrase か tag のいずれかが必要です。') if !values[:phrase].present? && !values[:tag].present?
    end

    rule(:action) do
      unless [nil, 'register', 'unregister'].member?(value)
        key.failure('actionは "register" または "unregister" で指定してください。')
      end
    end
  end
end
