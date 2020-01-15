require 'dry-validation'

module Mulukhiya
  class FilterCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:phrase).value(:string)
      optional(:tag).value(:string)
      optional(:action).value(:string)
    end

    rule(:command) do
      key.failure('command: が正しくありません。') unless value == 'filter'
    end

    rule(:phrase, :tag) do
      if !values[:phrase].present? && !values[:tag].present?
        key.failure('phrase: か tag: のいずれかが必要です。')
      end
    end

    rule(:action) do
      unless [nil, 'register', 'unregister'].member?(value)
        key.failure('action: は "register" または "unregister" で指定してください。')
      end
    end
  end
end
